import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXNN

/// Tencent's `hunyuan_v1_dense` is structurally identical to Qwen3
/// (GQA + QK-norm + SwiGLU + RoPE + RMSNorm + tied embeddings). The only
/// weight-naming difference is that Hunyuan ships QK-norm tensors as
/// `query_layernorm` / `key_layernorm` instead of `q_norm` / `k_norm`.
///
/// We can't subclass `Qwen3Model` (non-open across module boundaries) and
/// the inner Qwen3 components are non-public — so this file ports the
/// minimum needed model in ~140 lines using Hunyuan's exact tensor names.

struct HunyuanConfiguration: Codable, Sendable {
    let hiddenSize: Int
    let hiddenLayers: Int
    let intermediateSize: Int
    let attentionHeads: Int
    let kvHeads: Int
    let headDim: Int
    let rmsNormEps: Float
    let vocabularySize: Int
    let ropeTheta: Float
    let tieWordEmbeddings: Bool
    let maxPositionEmbeddings: Int

    enum CodingKeys: String, CodingKey {
        case hiddenSize = "hidden_size"
        case hiddenLayers = "num_hidden_layers"
        case intermediateSize = "intermediate_size"
        case attentionHeads = "num_attention_heads"
        case kvHeads = "num_key_value_heads"
        case headDim = "head_dim"
        case rmsNormEps = "rms_norm_eps"
        case vocabularySize = "vocab_size"
        case ropeTheta = "rope_theta"
        case tieWordEmbeddings = "tie_word_embeddings"
        case maxPositionEmbeddings = "max_position_embeddings"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hiddenSize = try c.decode(Int.self, forKey: .hiddenSize)
        self.hiddenLayers = try c.decode(Int.self, forKey: .hiddenLayers)
        self.intermediateSize = try c.decode(Int.self, forKey: .intermediateSize)
        self.attentionHeads = try c.decode(Int.self, forKey: .attentionHeads)
        self.kvHeads = try c.decode(Int.self, forKey: .kvHeads)
        self.headDim = try c.decodeIfPresent(Int.self, forKey: .headDim)
            ?? (self.hiddenSize / self.attentionHeads)
        self.rmsNormEps = try c.decode(Float.self, forKey: .rmsNormEps)
        self.vocabularySize = try c.decode(Int.self, forKey: .vocabularySize)
        self.ropeTheta = try c.decodeIfPresent(Float.self, forKey: .ropeTheta) ?? 10_000
        self.tieWordEmbeddings = try c.decodeIfPresent(Bool.self, forKey: .tieWordEmbeddings) ?? true
        self.maxPositionEmbeddings = try c.decodeIfPresent(Int.self, forKey: .maxPositionEmbeddings) ?? 32_768
    }
}

private final class HunyuanAttention: Module {
    let attentionHeads: Int
    let kvHeads: Int
    let scale: Float

    @ModuleInfo(key: "q_proj") var wq: Linear
    @ModuleInfo(key: "k_proj") var wk: Linear
    @ModuleInfo(key: "v_proj") var wv: Linear
    @ModuleInfo(key: "o_proj") var wo: Linear

    @ModuleInfo(key: "query_layernorm") var qNorm: RMSNorm
    @ModuleInfo(key: "key_layernorm") var kNorm: RMSNorm

    let rope: RoPE

    init(_ args: HunyuanConfiguration) {
        self.attentionHeads = args.attentionHeads
        self.kvHeads = args.kvHeads
        let dim = args.hiddenSize
        let headDim = args.headDim
        let headDimFloat: Float = Float(headDim)
        self.scale = 1.0 / headDimFloat.squareRoot()

        _wq.wrappedValue = Linear(dim, args.attentionHeads * headDim, bias: false)
        _wk.wrappedValue = Linear(dim, args.kvHeads * headDim, bias: false)
        _wv.wrappedValue = Linear(dim, args.kvHeads * headDim, bias: false)
        _wo.wrappedValue = Linear(args.attentionHeads * headDim, dim, bias: false)

        _qNorm.wrappedValue = RMSNorm(dimensions: headDim, eps: args.rmsNormEps)
        _kNorm.wrappedValue = RMSNorm(dimensions: headDim, eps: args.rmsNormEps)

        self.rope = RoPE(
            dimensions: headDim, traditional: false, base: args.ropeTheta, scale: 1)
    }

    func callAsFunction(
        _ x: MLXArray, mask: MLXFast.ScaledDotProductAttentionMaskMode, cache: KVCache?
    ) -> MLXArray {
        let (B, L) = (x.dim(0), x.dim(1))

        var queries = wq(x)
        var keys = wk(x)
        var values = wv(x)

        queries = qNorm(queries.reshaped(B, L, attentionHeads, -1)).transposed(0, 2, 1, 3)
        keys = kNorm(keys.reshaped(B, L, kvHeads, -1)).transposed(0, 2, 1, 3)
        values = values.reshaped(B, L, kvHeads, -1).transposed(0, 2, 1, 3)

        queries = applyRotaryPosition(rope, to: queries, cache: cache)
        keys = applyRotaryPosition(rope, to: keys, cache: cache)

        let output = attentionWithCacheUpdate(
            queries: queries, keys: keys, values: values,
            cache: cache, scale: scale, mask: mask
        )
        .transposed(0, 2, 1, 3)
        .reshaped(B, L, -1)

        return wo(output)
    }
}

private final class HunyuanMLP: Module, UnaryLayer {
    @ModuleInfo(key: "gate_proj") var gate: Linear
    @ModuleInfo(key: "up_proj") var up: Linear
    @ModuleInfo(key: "down_proj") var down: Linear

    init(dim: Int, hiddenDim: Int) {
        _gate.wrappedValue = Linear(dim, hiddenDim, bias: false)
        _up.wrappedValue = Linear(dim, hiddenDim, bias: false)
        _down.wrappedValue = Linear(hiddenDim, dim, bias: false)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        down(silu(gate(x)) * up(x))
    }
}

private final class HunyuanBlock: Module {
    @ModuleInfo(key: "self_attn") var attention: HunyuanAttention
    let mlp: HunyuanMLP
    @ModuleInfo(key: "input_layernorm") var inputLayerNorm: RMSNorm
    @ModuleInfo(key: "post_attention_layernorm") var postAttentionLayerNorm: RMSNorm

    init(_ args: HunyuanConfiguration) {
        _attention.wrappedValue = HunyuanAttention(args)
        self.mlp = HunyuanMLP(dim: args.hiddenSize, hiddenDim: args.intermediateSize)
        _inputLayerNorm.wrappedValue = RMSNorm(dimensions: args.hiddenSize, eps: args.rmsNormEps)
        _postAttentionLayerNorm.wrappedValue = RMSNorm(
            dimensions: args.hiddenSize, eps: args.rmsNormEps)
    }

    func callAsFunction(
        _ x: MLXArray, mask: MLXFast.ScaledDotProductAttentionMaskMode, cache: KVCache?
    ) -> MLXArray {
        var r = attention(inputLayerNorm(x), mask: mask, cache: cache)
        let h = x + r
        r = mlp(postAttentionLayerNorm(h))
        return h + r
    }
}

private final class HunyuanInner: Module {
    @ModuleInfo(key: "embed_tokens") var embedTokens: Embedding
    fileprivate let layers: [HunyuanBlock]
    let norm: RMSNorm

    init(_ args: HunyuanConfiguration) {
        precondition(args.vocabularySize > 0)
        _embedTokens.wrappedValue = Embedding(
            embeddingCount: args.vocabularySize, dimensions: args.hiddenSize)
        self.layers = (0 ..< args.hiddenLayers).map { _ in HunyuanBlock(args) }
        self.norm = RMSNorm(dimensions: args.hiddenSize, eps: args.rmsNormEps)
    }

    func callAsFunction(_ inputs: MLXArray, cache: [KVCache]? = nil) -> MLXArray {
        var h = embedTokens(inputs)
        let mask = createAttentionMask(h: h, cache: cache?.first)
        for (i, layer) in layers.enumerated() {
            h = layer(h, mask: mask, cache: cache?[i])
        }
        return norm(h)
    }
}

final class HunyuanDenseModel: Module, LLMModel, KVCacheDimensionProvider, @unchecked Sendable {
    let vocabularySize: Int
    let kvHeads: [Int]
    fileprivate let model: HunyuanInner
    private let configuration: HunyuanConfiguration

    @ModuleInfo(key: "lm_head") var lmHead: Linear?

    init(_ args: HunyuanConfiguration) {
        self.configuration = args
        self.vocabularySize = args.vocabularySize
        self.kvHeads = (0 ..< args.hiddenLayers).map { _ in args.kvHeads }
        self.model = HunyuanInner(args)
        if !args.tieWordEmbeddings {
            _lmHead.wrappedValue = Linear(args.hiddenSize, args.vocabularySize, bias: false)
        }
    }

    func callAsFunction(_ inputs: MLXArray, cache: [KVCache]?) -> MLXArray {
        var out = model(inputs, cache: cache)
        if let lmHead {
            out = lmHead(out)
        } else {
            out = model.embedTokens.asLinear(out)
        }
        return out
    }

    func sanitize(weights: [String: MLXArray]) -> [String: MLXArray] {
        var weights = weights
        if configuration.tieWordEmbeddings {
            weights["lm_head.weight"] = nil
        }
        return weights
    }
}

extension HunyuanDenseModel: LoRAModel {
    var loraLayers: [Module] {
        model.layers
    }
}

@MainActor
enum HunyuanRegistration {
    private static var didRegister = false

    static func registerIfNeeded() async {
        guard !didRegister else { return }
        didRegister = true
        let creator: @Sendable (Data) throws -> any LanguageModel = { data in
            let decoder = JSONDecoder()
            decoder.allowsJSON5 = true
            let config = try decoder.decode(HunyuanConfiguration.self, from: data)
            return HunyuanDenseModel(config)
        }
        let aliases = ["hunyuan_v1_dense", "hunyuan", "hunyuan_dense", "hy_mt", "hunyuan_v1"]
        for alias in aliases {
            await LLMTypeRegistry.shared.registerModelType(alias, creator: creator)
        }
        print("[Hunyuan] Registered architectures: \(aliases.joined(separator: ", "))")
    }
}
