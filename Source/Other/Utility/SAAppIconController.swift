//
//  SAAppIconController.swift
//  Sequel Ace
//
//  Copyright © 2026 Sequel-Ace. All rights reserved.
//

import AppKit

enum SAAppIconAppearance: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var imageName: String? {
        switch self {
        case .system: return nil
        case .light: return "AppIconLight"
        case .dark: return "AppIconDark"
        }
    }
}

/// Overrides only the running app's Dock icon; window appearance remains independent.
@objc final class SAAppIconController: NSObject {
    // Keep in sync with PreferenceDefaults.plist.
    static let preferenceKey = "DockIconAppearance"

    private static let shared = SAAppIconController(
        imageProvider: { NSImage(named: $0) },
        applyImage: { NSApplication.shared.applicationIconImage = $0 }
    )

    private let imageProvider: (String) -> NSImage?
    private let applyImage: (NSImage?) -> Void
    private var appliedAppearance: SAAppIconAppearance?

    init(imageProvider: @escaping (String) -> NSImage?, applyImage: @escaping (NSImage?) -> Void) {
        self.imageProvider = imageProvider
        self.applyImage = applyImage
        super.init()
    }

    @objc static func applyPreference() {
        shared.update(using: .standard)
    }

    func update(using defaults: UserDefaults) {
        assert(Thread.isMainThread)
        let appearance = SAAppIconAppearance(rawValue: defaults.integer(forKey: Self.preferenceKey)) ?? .system
        // Defaults notifications also fire for unrelated preferences and query history.
        guard appearance != appliedAppearance else { return }

        if let name = appearance.imageName {
            guard let image = imageProvider(name) else {
                // Restore the native icon if an asset is unavailable, and allow a retry.
                applyImage(nil)
                appliedAppearance = nil
                return
            }
            applyImage(Self.dockImage(from: image))
        } else {
            // nil restores native light/dark/tinted behavior, including future OS styles.
            applyImage(nil)
        }
        appliedAppearance = appearance
    }

    static func dockImage(from image: NSImage) -> NSImage {
        // Icon Composer exports the shape edge-to-edge. Match the 10% transparent
        // margins of the compiled macOS icon so an override does not enlarge the tile.
        let size = NSSize(width: 512, height: 512)
        return NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1))
            return true
        }
    }
}
