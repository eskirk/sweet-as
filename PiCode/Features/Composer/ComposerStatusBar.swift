import SwiftUI

/// session facts stay separate from the controls so narrow windows never hide send.
struct ComposerStatusBar: View {
    var preferences: PreferencesStore
    var stats: PiSessionStats?
    var controller: PiSessionController
    @State private var showingMCP = false

    private struct Indicator: Identifiable {
        var id: String
        var symbol: String
        var value: String
        var detail: String
    }

    var body: some View {
        if !indicators.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 6) {
                ForEach(indicators) { indicator in
                    if indicator.id == "mcp" {
                        Button { showingMCP = true } label: {
                            statusLabel(indicator)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingMCP) { mcpPopover }
                    } else {
                        statusLabel(indicator)
                    }
                }
            }
            .padding(.top, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Session status")
        }
    }

    private func statusLabel(_ indicator: Indicator) -> some View {
        Label(indicator.value, systemImage: indicator.symbol)
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .help(indicator.detail)
            .accessibilityLabel(indicator.detail)
    }

    private var mcpPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MCP servers").font(.headline)
            if let snapshot = controller.mcpStatusSnapshot {
                ScrollView {
                    Text(snapshot.text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                Text("Last reported \(snapshot.checkedAt.formatted(date: .omitted, time: .standard)). Refresh to check again.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let status = controller.mcpExtensionStatus {
                Text(status).textSelection(.enabled)
            } else {
                Text("No status report yet. Refresh asks this session's /mcp command; it does not open new server connections.")
                    .foregroundStyle(.secondary)
            }
            if let error = controller.mcpInspectionError {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            if !controller.canInspectMCP && !controller.isInspectingMCP {
                Text("Refresh requires an idle, connected session that advertises the /mcp extension command. Custom MCP extensions may report through the session's notifications or dialogs instead.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(controller.isInspectingMCP ? "Checking…" : "Refresh status") {
                Task { await controller.inspectMCP() }
            }
            .disabled(!controller.canInspectMCP)
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
    }

    private var indicators: [Indicator] {
        var result: [Indicator] = []
        if preferences.showComposerTokens {
            let usage = stats.flatMap { $0.hasTokenUsage ? $0.tokens : nil }
            let total = usage.map { Self.number($0.totalTokens) } ?? "—"
            let detail = usage.map {
                "Session tokens: \($0.totalTokens.formatted()). Input: \($0.input.formatted()), output: \($0.output.formatted()), cache read: \($0.cacheRead.formatted()), cache write: \($0.cacheWrite.formatted())."
            } ?? "Session token usage is not available from this harness yet."
            result.append(Indicator(id: "tokens", symbol: "number", value: "Tokens \(total)", detail: detail))
        }
        if preferences.showComposerContext {
            let context = stats?.contextUsage
            let percent = (context?.percent).flatMap { $0.isFinite ? $0 : nil }
            let value = percent.map { "Context \($0.formatted(.number.precision(.fractionLength(0))))%" }
                ?? (context?.tokens).map { "Context \(Self.number($0))" }
                ?? "Context —"
            let detail: String
            if let tokens = context?.tokens, let window = context?.contextWindow, window > 0 {
                detail = "Current context: \(tokens.formatted()) of \(window.formatted()) tokens. This is not cumulative session usage."
            } else if let percent {
                detail = "Current context: \(percent.formatted(.number.precision(.fractionLength(1))))% of the model's limit."
            } else {
                detail = "Current context usage is not available from this harness yet."
            }
            result.append(Indicator(id: "context", symbol: "chart.pie", value: value, detail: detail))
        }
        if preferences.showComposerCost {
            let cost = stats.flatMap { $0.hasCost && $0.cost.isFinite && $0.cost >= 0 ? $0.cost : nil }
            let value = cost.map { $0.formatted(.currency(code: "USD").precision(.fractionLength(4))) } ?? "—"
            result.append(Indicator(id: "cost", symbol: "dollarsign.circle", value: "Cost \(value)", detail: cost == nil
                ? "Session cost is not available from this harness yet."
                : "Estimated session cost: \(value) USD, reported by the harness. This is not your account's billed balance; subscription pricing may differ."))
        }
        if preferences.showComposerMCP {
            let value = controller.mcpStatusSnapshot.map { "MCP \($0.serverCount) servers" }
                ?? controller.mcpExtensionStatus.map { "MCP \($0)" }
                ?? "MCP · inspect"
            result.append(Indicator(id: "mcp", symbol: "server.rack", value: value,
                                    detail: "Inspect MCP servers reported by this session. Counts include disabled servers and are a last-reported snapshot, not a live connection count."))
        }
        return result
    }

    private static func number(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
}
