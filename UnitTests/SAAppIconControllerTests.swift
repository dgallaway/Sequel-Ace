import XCTest
import AppKit

final class SAAppIconControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SAAppIconControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testNewInstallationUsesNativeIconWithoutLoadingAssets() {
        var applied: [NSImage?] = []
        let controller = SAAppIconController(imageProvider: { _ in
            XCTFail("System selection should use macOS's native icon")
            return nil
        }, applyImage: { applied.append($0) })

        controller.update(using: defaults)

        XCTAssertEqual(applied.count, 1)
        XCTAssertNil(applied[0])
    }

    func testLightIconRemainsSelectedWithDarkWindowAppearance() {
        defaults.set(2, forKey: "Appearance")
        defaults.set(SAAppIconAppearance.light.rawValue, forKey: SAAppIconController.preferenceKey)
        var loaded: [String] = []
        var applied: [NSImage?] = []
        let controller = SAAppIconController(imageProvider: {
            loaded.append($0)
            return NSImage(size: NSSize(width: 1024, height: 1024))
        }, applyImage: { applied.append($0) })

        controller.update(using: defaults)
        defaults.set(1, forKey: "Appearance")
        controller.update(using: defaults)

        XCTAssertEqual(loaded, ["AppIconLight"])
        XCTAssertEqual(applied.count, 1)
        XCTAssertNotNil(applied[0])
        XCTAssertEqual(defaults.integer(forKey: "Appearance"), 1)
    }

    func testSwitchingDarkThenSystemRestoresNativeBehavior() {
        var loaded: [String] = []
        var applied: [NSImage?] = []
        let controller = SAAppIconController(imageProvider: {
            loaded.append($0)
            return NSImage(size: NSSize(width: 1024, height: 1024))
        }, applyImage: { applied.append($0) })
        defaults.set(SAAppIconAppearance.dark.rawValue, forKey: SAAppIconController.preferenceKey)
        controller.update(using: defaults)
        defaults.set(SAAppIconAppearance.system.rawValue, forKey: SAAppIconController.preferenceKey)
        controller.update(using: defaults)

        XCTAssertEqual(loaded, ["AppIconDark"])
        XCTAssertEqual(applied.count, 2)
        XCTAssertNotNil(applied[0])
        XCTAssertNil(applied[1])
    }

    func testSavedSelectionIsAppliedByNewController() {
        defaults.set(SAAppIconAppearance.light.rawValue, forKey: SAAppIconController.preferenceKey)
        var loaded: [String] = []
        for _ in 0..<2 {
            let controller = SAAppIconController(imageProvider: {
                loaded.append($0)
                return NSImage(size: NSSize(width: 1024, height: 1024))
            }, applyImage: { _ in })
            controller.update(using: defaults)
        }
        XCTAssertEqual(loaded, ["AppIconLight", "AppIconLight"])
    }

    func testUnknownSelectionFallsBackToNativeIcon() {
        defaults.set(999, forKey: SAAppIconController.preferenceKey)
        var applied: [NSImage?] = []
        let controller = SAAppIconController(imageProvider: { _ in
            XCTFail("Unknown preference must not load an asset")
            return nil
        }, applyImage: { applied.append($0) })
        controller.update(using: defaults)
        XCTAssertEqual(applied.count, 1)
        XCTAssertNil(applied[0])
    }

    func testMissingAssetRestoresNativeIconAndCanRetry() {
        defaults.set(SAAppIconAppearance.dark.rawValue, forKey: SAAppIconController.preferenceKey)
        var image: NSImage?
        var applied: [NSImage?] = []
        let controller = SAAppIconController(imageProvider: { _ in image }, applyImage: { applied.append($0) })
        controller.update(using: defaults)
        image = NSImage(size: NSSize(width: 1024, height: 1024))
        controller.update(using: defaults)
        XCTAssertEqual(applied.count, 2)
        XCTAssertNil(applied[0])
        XCTAssertNotNil(applied[1])
    }

    func testDockImageRetainsTransparentMargins() throws {
        let source = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let image = SAAppIconController.dockImage(from: source)
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(image.size, NSSize(width: 512, height: 512))
        let middle = bitmap.pixelsWide / 2
        XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 0, y: middle)).alphaComponent, 0)
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: middle, y: middle)).alphaComponent, 0.99)
    }
}
