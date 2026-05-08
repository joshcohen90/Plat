import SwiftUI
import PlatKit

/// Shown the first time the app launches, and re-accessible from Settings.
/// Frames the value prop and prepares the user for the location permission prompt.
struct OnboardingView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

            VStack(spacing: 12) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(LineColor.color(for: "6"))
                Text("Welcome to Plat")
                    .font(.title.weight(.heavy))
                Text("Live MTA arrivals at the stops you actually take.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 18) {
                Bullet(symbol: "plus.circle.fill",
                       title: "Save your stops",
                       detail: "Pick the subway lines and bus routes you ride. Multiple lines at one corner can be combined into a single location.")
                Bullet(symbol: "location.fill.viewfinder",
                       title: "Smart by location",
                       detail: "Your widget shows the next arrival at the 3 saved locations closest to you. As you move between neighborhoods, it updates.")
                Bullet(symbol: "rectangle.stack.fill.badge.plus",
                       title: "Lock & home screen widgets",
                       detail: "Quick-glance arrivals without opening the app. Tap the refresh button on the widget for fresh data on demand.")
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 8) {
                Button {
                    // First-tier prompt: When-In-Use. We escalate to Always
                    // later, after the user has saved their first stop, since
                    // back-to-back prompts are rejected by App Review.
                    LocationManager.shared.requestAuthorization()
                    onDone()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Link(destination: AppConfig.privacyURL) {
                    Text("Privacy Policy")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled()
    }
}

private struct Bullet: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
