import SwiftUI
import PlatKit

struct SettingsView: View {
    @EnvironmentObject private var saved: SavedStopsStore
    @EnvironmentObject private var location: LocationManager
    @State private var showResetConfirm = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LocationStatusRow(authorization: location.authorization)
                }

                Section("About") {
                    Row(label: "Version", value: Self.versionString)
                    Link(destination: AppConfig.privacyURL) {
                        Row(label: "Privacy Policy", trailingSymbol: "arrow.up.right.square")
                    }
                    Button {
                        showOnboarding = true
                    } label: {
                        Row(label: "Show Welcome", trailingSymbol: "sparkles")
                    }
                }

                Section("Data") {
                    Row(label: "Saved Stops", value: "\(saved.stops.count)")
                    Row(label: "Locations", value: "\(saved.resolvedGroups.count)")
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Remove All Saved Stops", systemImage: "trash")
                    }
                    .disabled(saved.stops.isEmpty)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Transit data provided by the Metropolitan Transportation Authority.")
                        Link("api.mta.info", destination: URL(string: "https://api.mta.info")!)
                            .font(.footnote)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Attribution")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Remove all saved stops?",
                                isPresented: $showResetConfirm,
                                titleVisibility: .visible) {
                Button("Remove All", role: .destructive) {
                    for stop in saved.stops { saved.remove(stop) }
                    Task { await RefreshCoordinator.shared.refresh(reason: .savedStopsChanged) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear your widget. You can re-add stops at any time.")
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView { showOnboarding = false }
            }
        }
    }

    private static var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

private struct Row: View {
    let label: String
    var value: String? = nil
    var trailingSymbol: String? = nil

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.primary)
            Spacer()
            if let value {
                Text(value).foregroundStyle(.secondary).font(.body.monospacedDigit())
            }
            if let trailingSymbol {
                Image(systemName: trailingSymbol).foregroundStyle(.tertiary).font(.footnote)
            }
        }
    }
}

private struct LocationStatusRow: View {
    let authorization: CLAuthorizationStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if needsAction {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch authorization {
        case .authorizedAlways: "location.fill.viewfinder"
        case .authorizedWhenInUse: "location.fill"
        case .denied, .restricted: "location.slash.fill"
        default: "location"
        }
    }

    private var tint: Color {
        switch authorization {
        case .authorizedAlways, .authorizedWhenInUse: .green
        case .denied, .restricted: .red
        default: .secondary
        }
    }

    private var title: String {
        switch authorization {
        case .authorizedAlways: "Location: Always"
        case .authorizedWhenInUse: "Location: While Using"
        case .denied: "Location off"
        case .restricted: "Location restricted"
        default: "Location not set"
        }
    }

    private var detail: String {
        switch authorization {
        case .authorizedAlways: "The widget can update as you move."
        case .authorizedWhenInUse: "Closest 3 won't update in the background. Allow Always for best experience."
        case .denied: "Add stops still works — distance ranking is disabled."
        case .restricted: "Location is restricted on this device."
        default: "Open the Saved tab to grant access."
        }
    }

    private var needsAction: Bool {
        switch authorization {
        case .authorizedWhenInUse, .denied: true
        default: false
        }
    }
}

import CoreLocation
import UIKit
