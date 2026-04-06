import Foundation

protocol OnboardingStore: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
}

final class UserDefaultsOnboardingStore: OnboardingStore {
    private let defaults: UserDefaults
    private let completionKey: String

    init(defaults: UserDefaults = .standard, completionKey: String = "hasCompletedOnboarding") {
        self.defaults = defaults
        self.completionKey = completionKey
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: completionKey) }
        set { defaults.set(newValue, forKey: completionKey) }
    }
}
