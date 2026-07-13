import SwiftUI
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, persian
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:  return "language.system".loc
        case .english: return "English"
        case .persian: return "فارسی"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system:  return nil
        case .english: return "en"
        case .persian: return "fa"
        }
    }
}

/// Drives in-app language override and the resulting layout direction.
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        self.language = AppLanguage(rawValue: raw) ?? .system
    }

    /// Resolves `.system` to the concrete language currently in effect.
    var effectiveLanguage: AppLanguage {
        switch language {
        case .system:
            let code = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
            return code == "fa" ? .persian : .english
        default:
            return language
        }
    }

    var layoutDirection: LayoutDirection {
        effectiveLanguage == .persian ? .rightToLeft : .leftToRight
    }

    /// The bundle to pull localized strings from for the override language.
    var bundle: Bundle {
        guard let id = effectiveLanguage.localeIdentifier,
              let path = Bundle.main.path(forResource: id, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    var locale: Locale {
        Locale(identifier: effectiveLanguage == .persian ? "fa_IR" : "en_US")
    }
}

extension String {
    /// Localize honoring the in-app language override.
    var loc: String {
        NSLocalizedString(self, bundle: LocalizationManager.shared.bundle, comment: "")
    }

    func loc(_ args: CVarArg...) -> String {
        String(format: self.loc, arguments: args)
    }
}
