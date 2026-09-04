//
//  SAAppIconPreferenceView.swift
//  Sequel Ace
//
//  Copyright © 2026 Sequel-Ace. All rights reserved.
//

import SwiftUI

/// Hosts the SwiftUI preference beside the existing appearance controls.
@objc final class SAAppIconPreferenceHostingView: NSView {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installContent()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installContent()
    }

    private func installContent() {
        let content = NSHostingView(rootView: SAAppIconPreferenceView())
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

final class SAAppIconPreferenceModel: ObservableObject {
    @Published var selection = SAAppIconAppearance.system
    @Published var errorMessage = ""
    @Published var showingError = false

    init() { reload() }

    func reload() {
        selection = SAAppIconAppearance(rawValue: UserDefaults.standard.integer(forKey: SAAppIconController.preferenceKey)) ?? .system
    }

    func apply() {
        errorMessage = ""
        do {
            if try SAPersistentAppIconController.shared.select(selection, using: .standard) {
                SAAppIconController.applyPreference()
            } else {
                reload()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            reload()
        }
    }
}

struct SAAppIconPreferenceView: View {
    @StateObject private var model = SAAppIconPreferenceModel()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(NSLocalizedString("App icon:", comment: "General preferences: independent app icon appearance"))
                .frame(width: 150, height: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Picker(NSLocalizedString("App icon:", comment: "General preferences: independent app icon appearance"), selection: $model.selection) {
                        Text(NSLocalizedString("System", comment: "App icon appearance: follow macOS icon settings"))
                            .tag(SAAppIconAppearance.system)
                        Text(NSLocalizedString("Light", comment: "App icon appearance: always use the light icon"))
                            .tag(SAAppIconAppearance.light)
                        Text(NSLocalizedString("Dark", comment: "App icon appearance: always use the dark icon"))
                            .tag(SAAppIconAppearance.dark)
                    }
                    .labelsHidden()
                    .accessibilityIdentifier("AppIconAppearance")
                    Button(NSLocalizedString("Apply Icon", comment: "Apply the selected icon in Finder and the Dock")) { model.apply() }
                }
                Text(NSLocalizedString("Keeps the chosen icon in Finder and the Dock when Sequel Ace is closed.", comment: "Persistent app icon preference description"))
                    .font(.system(size: NSFont.smallSystemFontSize))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .onAppear { model.reload() }
        .alert(NSLocalizedString("Could Not Change App Icon", comment: "App icon preference error title"), isPresented: $model.showingError) {
            Button(NSLocalizedString("OK", comment: "Dismiss app icon error"), role: .cancel) { }
        } message: {
            Text(model.errorMessage)
        }
    }
}
