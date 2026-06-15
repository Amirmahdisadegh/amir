import Foundation

/// The AI services CalSnap can use for food recognition. Each has its own API
/// key, selectable model, and request format.
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case claude
    case openai
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "ChatGPT"
        case .gemini: return "Gemini"
        }
    }

    var maker: String {
        switch self {
        case .claude: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google"
        }
    }

    var symbol: String {
        switch self {
        case .claude: return "sparkle"
        case .openai: return "bubble.left.and.text.bubble.right.fill"
        case .gemini: return "diamond.fill"
        }
    }

    /// Vision-capable model presets shown as quick-pick chips.
    var models: [String] {
        switch self {
        case .claude:
            return ["claude-sonnet-4-6", "claude-opus-4-8", "claude-haiku-4-5"]
        case .openai:
            return ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini"]
        case .gemini:
            return ["gemini-2.0-flash", "gemini-2.5-pro", "gemini-1.5-pro", "gemini-1.5-flash"]
        }
    }

    var defaultModel: String { models[0] }

    /// Where to create an API key.
    var consoleURL: String {
        switch self {
        case .claude: return "console.anthropic.com"
        case .openai: return "platform.openai.com/api-keys"
        case .gemini: return "aistudio.google.com/apikey"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .claude: return "sk-ant-…"
        case .openai: return "sk-…"
        case .gemini: return "AIza…"
        }
    }

    var keychainKey: String { "calsnap.\(rawValue).apikey" }
    var modelDefaultsKey: String { "calsnap.\(rawValue).model" }
}
