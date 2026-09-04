//
//  SAPersistentAppIconController.swift
//  Sequel Ace
//
//  Copyright © 2026 Sequel-Ace. All rights reserved.
//

import AppKit
import UniformTypeIdentifiers

/// Uses Finder's custom-icon API for the installed copy selected by the user.
/// The executable and bundled icon assets are never rewritten.
@objc final class SAPersistentAppIconController: NSObject {
    static let shared = SAPersistentAppIconController()
    static let bookmarkKey = "AppIconApplicationBookmark"

    enum Failure: LocalizedError {
        case missingImage, differentApplication, cannotApply

        var errorDescription: String? {
            switch self {
            case .missingImage:
                return NSLocalizedString("The selected app icon could not be loaded.", comment: "App icon preference: missing bundled image")
            case .differentApplication:
                return NSLocalizedString("Select the copy of Sequel Ace that is currently running.", comment: "App icon preference: the selected app must be this exact installation")
            case .cannotApply:
                return NSLocalizedString("macOS could not change this app's icon. Check that you have permission to modify this copy of Sequel Ace.", comment: "App icon preference: Finder could not write the custom icon")
            }
        }
    }

    private let applicationURL: URL
    private let imageProvider: (String) -> NSImage?
    private let writeIcon: (NSImage?, URL) -> Bool
    private let requestAccess: (URL) -> URL?
    private let makeBookmark: (URL) throws -> Data
    private let resolveBookmark: (Data) throws -> URL

    init(
        applicationURL: URL = Bundle.main.bundleURL,
        imageProvider: @escaping (String) -> NSImage? = { NSImage(named: $0) },
        writeIcon: @escaping (NSImage?, URL) -> Bool = { NSWorkspace.shared.setIcon($0, forFile: $1.path, options: []) },
        requestAccess: @escaping (URL) -> URL? = SAPersistentAppIconController.chooseApplication,
        makeBookmark: @escaping (URL) throws -> Data = { try $0.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) },
        resolveBookmark: @escaping (Data) throws -> URL = SAPersistentAppIconController.resolveApplicationBookmark
    ) {
        self.applicationURL = applicationURL
        self.imageProvider = imageProvider
        self.writeIcon = writeIcon
        self.requestAccess = requestAccess
        self.makeBookmark = makeBookmark
        self.resolveBookmark = resolveBookmark
        super.init()
    }

    /// A cancelled permission panel leaves both the stored choice and icons unchanged.
    @discardableResult
    func select(_ appearance: SAAppIconAppearance, using defaults: UserDefaults) throws -> Bool {
        assert(Thread.isMainThread)
        let image = try image(for: appearance)
        if let url = authorizedApplication(in: defaults),
           (try? apply(image, to: url, appearance: appearance, using: defaults)) == true {
            return true
        }
        guard let selectedURL = requestAccess(applicationURL) else { return false }
        guard isRunningApplication(selectedURL) else { throw Failure.differentApplication }
        guard try apply(image, to: selectedURL, appearance: appearance, using: defaults) else {
            throw Failure.cannotApply
        }
        return true
    }

    /// Reapply after an app update when the previous grant still resolves to this copy.
    /// Startup never opens a permission panel or modifies another installation.
    @objc static func restoreSavedPreference() {
        shared.restoreIfAuthorized(using: .standard)
    }

    func restoreIfAuthorized(using defaults: UserDefaults) {
        assert(Thread.isMainThread)
        guard let appearance = SAAppIconAppearance(rawValue: defaults.integer(forKey: SAAppIconController.preferenceKey)),
              appearance != .system,
              let url = authorizedApplication(in: defaults),
              let image = try? image(for: appearance) else { return }
        _ = try? apply(image, to: url, appearance: appearance, using: defaults)
    }

    private func image(for appearance: SAAppIconAppearance) throws -> NSImage? {
        guard let name = appearance.imageName else { return nil }
        guard let image = imageProvider(name) else { throw Failure.missingImage }
        return SAAppIconController.dockImage(from: image)
    }

    private func authorizedApplication(in defaults: UserDefaults) -> URL? {
        guard let data = defaults.data(forKey: Self.bookmarkKey),
              let url = try? resolveBookmark(data),
              isRunningApplication(url) else { return nil }
        return url
    }

    private func isRunningApplication(_ url: URL) -> Bool {
        url.isFileURL && url.resolvingSymlinksInPath().standardizedFileURL == applicationURL.resolvingSymlinksInPath().standardizedFileURL
    }

    private func apply(_ image: NSImage?, to url: URL, appearance: SAAppIconAppearance, using defaults: UserDefaults) throws -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        // Prepare the bookmark first, so a failed grant cannot leave a half-saved choice.
        let bookmark = try makeBookmark(url)
        guard writeIcon(image, url) else { return false }
        defaults.set(bookmark, forKey: Self.bookmarkKey)
        defaults.set(appearance.rawValue, forKey: SAAppIconController.preferenceKey)
        return true
    }

    private static func resolveApplicationBookmark(_ data: Data) throws -> URL {
        var stale = false
        return try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        // apply() replaces the bookmark with current data, including when it was stale.
    }

    private static func chooseApplication(_ applicationURL: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("Change App Icon", comment: "App icon permission panel title")
        panel.message = String(format: NSLocalizedString("Select %@ to change its icon in Finder and the Dock.", comment: "App icon permission panel; placeholder is the running app's file name"), applicationURL.lastPathComponent)
        panel.prompt = NSLocalizedString("Apply Icon", comment: "App icon permission panel action")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = applicationURL.deletingLastPathComponent()
        return panel.runModal() == .OK ? panel.url : nil
    }
}
