# iHunyuan

> A modern iOS 26 translation app powered by Tencent's [Hunyuan-MT 1.5](https://huggingface.co/tencent/HY-MT1.5-1.8B), running fully on-device via [Apple MLX](https://github.com/ml-explore/mlx-swift-lm). Liquid Glass UI throughout. 38 languages. No internet after the one-time model download.

Built by [Hanley Talks AI](https://www.youtube.com/@hanleytalksai).

---

## Why we built this

In late April 2026 Tencent open-sourced **Hunyuan-MT 1.5** — a 1.8B-parameter translation model that beats much larger commercial APIs (Microsoft Translator, Doubao Translator, Tower-Plus-72B, Qwen3-32B) at translation quality, while shrinking down to a 1.25-bit quantized version that runs at 440MB on phones with custom CPU kernels. They shipped an Android demo on day one. **No iOS port.**

We saw the news and thought: *this is exactly the kind of thing that shows where on-device LLMs are heading.* A 1.8B-param model that fits in your pocket, runs offline, and out-performs cloud APIs on a real-world task. So we built the iOS app Tencent didn't — natively in SwiftUI, using Apple MLX for inference, with all the iOS 26 polish (Liquid Glass, App Intents, SwiftData, Live perf telemetry).

The goal of this repo is **a hands-on demo** — give anyone with a modern iPhone a way to try a state-of-the-art on-device translation model in 60 seconds, see the perf numbers in real time, and get a feel for what local LLMs feel like in 2026.

If you find this useful, give the [YouTube channel](https://www.youtube.com/@hanleytalksai) a sub — that's where we cover this kind of thing.

## What it does

- **Chat-style translation** — type or paste, watch tokens stream in
- **38 languages** including Cantonese (粵語), Simplified & Traditional Chinese, English, Japanese, Korean, French, Spanish, German, Arabic, Hindi, Tibetan, Mongolian, and more
- **100% on-device inference** via MLX Swift on the Apple Silicon GPU's Neural Accelerators (A19 Pro / M5 family)
- **Live perf metrics** — time-to-first-token, tokens/sec, peak RAM, device tier — visualized with Swift Charts
- **iOS 26 deep integration** — Siri, Spotlight, Shortcuts, and Action Button via App Intents
- **Liquid Glass everywhere** — language pill, bubbles, composer, sheets, toolbar buttons
- **Per-line segment translation** for poetry, lyrics, and multi-paragraph text
- **SwiftData history** — translations persist across launches; long-press any bubble for Copy / Share / Re-translate

## Requirements

- **iOS 26.0+** (Liquid Glass APIs)
- **iPhone with 8 GB RAM** — iPhone 15 Pro or newer recommended
  - **iPhone 17 Pro / Pro Max** is the sweet spot — its A19 Pro is the first Apple chip with **Neural Accelerators in the GPU cores**, which gives MLX a major speedup
- **~2 GB free storage** for the 8-bit MLX model weights
- **Xcode 26+** with iOS 26 SDK
- [**XcodeGen**](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Setup

```bash
git clone https://github.com/hanley-tech/ihunyuan
cd ihunyuan
xcodegen generate
open iHunyuan.xcodeproj
```

In Xcode:

1. Select the `iHunyuan` target → **Signing & Capabilities** → set your **Team**
2. When Xcode prompts you to **Trust & Enable** Swift macros (`MLXHuggingFaceMacros`, `Tokenizers`, etc.) — click **Trust & Enable** for each
3. Pick your iPhone in the device selector
4. **⌘R**

The first launch downloads `mlx-community/HY-MT1.5-1.8B-8bit` (~1.9 GB) from Hugging Face. After that, everything runs offline — you can put the phone on airplane mode and translation still works.

## How to use it

### Translating

1. **Pick the target language** — tap the language pill at the top. Search by name (English, Chinese, native script, or BCP-47 code). Recents are pinned at the top.
2. **Type or paste source text** in the composer at the bottom. **Press send** (the up arrow) or tap return.
3. **Watch the translation stream in.** Each translation appears as a pair of bubbles — your source on the right, the translation on the left. The detected source language is shown as a small label.
4. **Long-press any translation bubble** for: Copy / Share / Re-translate (e.g., to a different target language) / Show speed.
5. **Tap the speed badge** under any bubble to see the full performance dashboard.

### Multi-line input (poetry, lyrics, paragraphs)

The model is trained on single-segment translations. iHunyuan automatically splits multi-line input on newlines and translates each line as its own segment, then rejoins them with the original line breaks. This preserves the structure of poems and lyrics. You can paste anything from a single sentence to a full song or news article.

### Voice input via Siri / Action Button

Set up an Action Button shortcut to "Translate with iHunyuan" and you can say *"Translate to French"* and dictate the source — Siri opens the app, the model loads, and the translation streams. You can also surface the same flow from Spotlight or the Shortcuts app.

### Languages we recommend testing first

- **English ↔ Simplified Chinese** — the workhorse pair, super tight quality
- **English ↔ Cantonese** — Tencent has good HK exposure in training data; HK-style code-switching ("我今日返office") works reasonably well
- **Japanese ↔ English** — surprisingly natural
- **Long-tail languages** — try Tibetan, Mongolian, Khmer, Burmese, Tamil. Hunyuan-MT supports 33 standard + 5 minority/dialect languages — way more than most on-device translators

## How to assess your performance

The whole point of this app is to give you a feel for **how fast on-device LLMs can be on your specific phone**. Tap the `⋯` menu in the top-right → **Performance** to see:

| Metric | What it means | What's good |
|---|---|---|
| **Tokens/sec** | How fast the model generates text after the first token. Higher is better. | iPhone 17 Pro Max: 25–40 tok/s. iPhone 15 Pro: 15–25. |
| **Time to first token (TTFT)** | Latency from "send" to first character appearing — includes prompt processing. Lower is better. | <1000 ms is fast. <500 ms feels instant. |
| **Peak RAM** | Highest memory the app reached. | The 8-bit model uses ~1.5–2 GB at runtime. Anything under 2.5 GB is healthy. |
| **Stop reason** (Xcode console) | Why generation ended. `eos` is the model finishing naturally. `maxTokens` would mean truncated output. | Almost always `eos`. |
| **Device tier label** | Auto-detected ("A19 Pro / Neural GPU", "A18 Pro", etc.) | A19 Pro → Neural Accelerators in GPU; biggest performance jump |

### How to read the charts

- **Tokens/sec line chart** — shows tok/s for each translation over time. If you see a downward trend, the device may be thermal-throttling (less common on iPhone 17 Pro family, more common on older devices doing back-to-back translations).
- **TTFT bar chart** — shorter inputs should have lower TTFT. If TTFT is consistently >2s on a Pro device, something's off (model not warmed up, phone in low-power mode, etc.).

### Things to try to feel the limits

1. **Translate the same short sentence repeatedly** — you'll see TTFT drop after the first run as the model warms up
2. **Paste a long article or song lyric** — watch tok/s under sustained load
3. **Try the same translation on different devices** — A19 Pro vs A18 Pro vs older. The A19 Pro's NA-equipped GPU should noticeably outpace its predecessor

### What you're NOT seeing

This app uses the **8-bit MLX quantization (1.9 GB)**, not Tencent's special **1.25-bit Sherry quantization (440 MB)**. The 1.25-bit version uses a custom CPU kernel that hasn't been ported to iOS yet — when it lands, expect another ~2× speedup and ~4× smaller footprint. Today's perf is already strong, but there's headroom.

## Architecture notes

- The Hunyuan dense architecture is structurally identical to Qwen3 (same GQA + QK-norm + SwiGLU + RoPE shape). The only difference is two tensor names: `query_layernorm` / `key_layernorm` instead of Qwen3's `q_norm` / `k_norm`. We ported a ~140-line model class ([`HunyuanRegistration.swift`](iHunyuan/Inference/HunyuanRegistration.swift)) that uses Hunyuan's exact tensor names directly via `@ModuleInfo` keys, then registered it with `LLMTypeRegistry.shared` for the `hunyuan_v1_dense` model_type.
- Translation is split per-line (see [`HunyuanMTService.swift`](iHunyuan/Inference/HunyuanMTService.swift)) because HY-MT is trained on single-segment translation — multi-paragraph inputs would otherwise sometimes stop after the first segment.
- App Intents expose translation to the entire iOS shell (Siri, Spotlight, Shortcuts, Action Button). See [`Intents/`](iHunyuan/Intents).
- The Xcode project is generated from `project.yml` via XcodeGen — keeps the repo clean of pbxproj merge conflicts.

## Roadmap (maybe)

- Voice input with `SFSpeechRecognizer`
- Share Extension for system-wide "translate selected text"
- Drop in the 1.25-bit Sherry GGUF when the iOS llama.cpp kernel ships
- Submit Hunyuan support upstream to `mlx-swift-lm` so we can drop our local registration

## Credits

- **Translation model** — [Tencent Hunyuan-MT 1.5](https://huggingface.co/tencent/HY-MT1.5-1.8B) by the Tencent Hunyuan team
- **Inference** — [Apple MLX Swift](https://github.com/ml-explore/mlx-swift-lm)
- **Tokenizers / weight downloads** — [Hugging Face Swift Transformers](https://github.com/huggingface/swift-transformers) & [Swift HuggingFace](https://github.com/huggingface/swift-huggingface)
- **App** — [Hanley Leung](https://www.youtube.com/@hanleytalksai)

## License

This app's source code: **MIT** — see [`LICENSE`](LICENSE).

The Hunyuan-MT model weights are Tencent's, released under [their own license](https://github.com/Tencent-Hunyuan/HY-MT) — review Tencent's terms before redistributing the model weights themselves. This app downloads the weights directly from Hugging Face at first launch; the weights are not bundled in this repo.
