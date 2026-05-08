import Foundation

public enum AppGroup {
    public static let identifier = "group.Joshua-Cohen.Plat"

    public static var defaults: UserDefaults {
        guard let d = UserDefaults(suiteName: identifier) else {
            fatalError("App Group \(identifier) not configured. See XCODE_SETUP.md step 4.")
        }
        return d
    }

    public static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            fatalError("App Group container missing for \(identifier)")
        }
        return url
    }
}
