import SwiftUI
import Charts

struct PerfStatsSheet: View {
    let samples: [PerfSample]
    let peakMemoryMB: Double
    let modelName: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard

                    if samples.isEmpty {
                        emptyState
                    } else {
                        speedCard
                        latencyCard
                        runsList
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(LinearGradient(
                colors: [Color.accentColor.opacity(0.10), .clear],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea())
            .navigationTitle("On-device speed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(DeviceInfo.tierLabel)
                    .font(.title3.weight(.semibold))
                Spacer()
                Image(systemName: "cpu.fill")
                    .foregroundStyle(.secondary)
            }
            Text(modelName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider().padding(.vertical, 4)
            HStack {
                stat(label: "Peak RAM", value: String(format: "%.0f MB", peakMemoryMB))
                Spacer()
                stat(label: "Runs", value: "\(samples.count)")
                Spacer()
                stat(label: "Avg tok/s", value: avgTpsLabel)
            }
        }
        .padding(18)
        .iHGlass(cornerRadius: 24)
    }

    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tokens / second")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(samples) { sample in
                LineMark(
                    x: .value("t", sample.timestamp),
                    y: .value("tok/s", sample.tokensPerSecond)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor.gradient)

                AreaMark(
                    x: .value("t", sample.timestamp),
                    y: .value("tok/s", sample.tokensPerSecond)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(
                    colors: [Color.accentColor.opacity(0.30), .clear],
                    startPoint: .top, endPoint: .bottom
                ))
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .frame(height: 110)
        }
        .padding(18)
        .iHGlass(cornerRadius: 24)
    }

    private var latencyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time to first token (ms)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(samples) { sample in
                BarMark(
                    x: .value("t", sample.timestamp),
                    y: .value("ms", sample.ttftMs)
                )
                .foregroundStyle(Color.accentColor.opacity(0.55))
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .frame(height: 90)
        }
        .padding(18)
        .iHGlass(cornerRadius: 24)
    }

    private var runsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent runs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(samples.suffix(8).reversed()) { sample in
                HStack {
                    Text(sample.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f tok/s", sample.tokensPerSecond))
                        .font(.caption.monospacedDigit().weight(.semibold))
                    Text("· \(Int(sample.ttftMs)) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("· \(sample.generatedTokens) tok")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .iHGlass(cornerRadius: 24)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "speedometer")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Translate something to see live performance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .iHGlass(cornerRadius: 24)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var avgTpsLabel: String {
        guard !samples.isEmpty else { return "—" }
        let mean = samples.map(\.tokensPerSecond).reduce(0, +) / Double(samples.count)
        return String(format: "%.1f", mean)
    }
}
