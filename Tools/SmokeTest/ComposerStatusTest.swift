import Foundation

@main
struct ComposerStatusTest {
    @MainActor
    static func main() throws {
        let suite = "sweet-as-composer-status-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        precondition(preferences.showComposerTokens && preferences.showComposerContext
                     && preferences.showComposerCost && preferences.showComposerMCP)
        preferences.showComposerTokens = false
        preferences.showComposerCost = false
        preferences.persist()
        let restored = PreferencesStore(defaults: defaults)
        precondition(!restored.showComposerTokens && restored.showComposerContext
                     && !restored.showComposerCost && restored.showComposerMCP)
        restored.showComposerContext = false
        restored.showComposerMCP = false
        restored.persist()
        let hidden = PreferencesStore(defaults: defaults)
        precondition(!hidden.showComposerTokens && !hidden.showComposerContext
                     && !hidden.showComposerCost && !hidden.showComposerMCP)

        let missing = PiSessionStats(json: .object([:]))
        precondition(!missing.hasTokenUsage && !missing.hasCost && missing.contextUsage == nil)
        let stats = PiSessionStats(json: try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"tokens":{"input":100,"output":20,"cacheRead":200,"cacheWrite":30},
         "cost":0.0123,"contextUsage":{"tokens":500,"contextWindow":1000,"percent":50}}
        """.utf8)))
        precondition(stats.hasTokenUsage && stats.tokens.totalTokens == 350)
        precondition(stats.hasCost && stats.cost == 0.0123)
        precondition(stats.contextUsage?.tokens == 500 && stats.contextUsage?.percent == 50)
        let compacted = PiSessionStats(json: try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"tokens":{"totalTokens":350},"cost":0,"contextUsage":{"tokens":null,"contextWindow":1000,"percent":null}}
        """.utf8)))
        precondition(compacted.hasCost && compacted.cost == 0)
        precondition(compacted.tokens.totalTokens == 350)
        precondition(compacted.contextUsage?.tokens == nil && compacted.contextUsage?.percent == nil)
        precondition(compacted.contextUsage?.contextWindow == 1000)
        print("Composer preferences and usage checks passed")
    }
}
