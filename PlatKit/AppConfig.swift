import Foundation

/// User-facing constants. Edit before each App Store submission.
public enum AppConfig {
    public static let privacyURL = URL(string: "https://example.com/plat/privacy")!
    public static let supportEmail = "support@example.com"
    public static let marketingURL = URL(string: "https://example.com/plat")!

    /// Cloudflare Worker proxy URL for bus arrivals (SIRI). Replace with your
    /// deployed Worker URL — see `workers/bus-proxy/README.md`. The proxy
    /// injects the bustime.mta.info API key server-side so it never ships
    /// in the iOS binary.
    public static let busProxyURL = URL(string: "https://plat-bus-proxy.example.workers.dev")!
}
