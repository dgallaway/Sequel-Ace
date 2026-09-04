import XCTest
import AppKit

final class SAPersistentAppIconControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private let applicationURL = URL(fileURLWithPath: "/Applications/Sequel Ace Test.app")
    private let bookmark = Data("test bookmark".utf8)

    override func setUp() {
        super.setUp()
        suiteName = "SAPersistentAppIconControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func controller(
        imageAvailable: Bool = true,
        request: @escaping (URL) -> URL?,
        resolve: ((Data) throws -> URL)? = nil,
        write: @escaping (NSImage?, URL) -> Bool
    ) -> SAPersistentAppIconController {
        SAPersistentAppIconController(
            applicationURL: applicationURL,
            imageProvider: { _ in imageAvailable ? NSImage(size: NSSize(width: 1024, height: 1024)) : nil },
            writeIcon: write,
            requestAccess: request,
            makeBookmark: { _ in self.bookmark },
            resolveBookmark: resolve ?? { _ in self.applicationURL }
        )
    }

    func testCancelledPermissionLeavesExistingSelectionUnchanged() throws {
        defaults.set(SAAppIconAppearance.dark.rawValue, forKey: SAAppIconController.preferenceKey)
        let subject = controller(request: { _ in nil }, write: { _, _ in
            XCTFail("Cancel must not change the Finder icon")
            return false
        })
        XCTAssertFalse(try subject.select(.light, using: defaults))
        XCTAssertEqual(defaults.integer(forKey: SAAppIconController.preferenceKey), SAAppIconAppearance.dark.rawValue)
        XCTAssertNil(defaults.data(forKey: SAPersistentAppIconController.bookmarkKey))
    }

    func testSuccessfulSelectionPersistsOnlyAfterFinderWrite() throws {
        defaults.set(2, forKey: "Appearance")
        let subject = controller(request: { $0 }, write: { image, url in
            XCTAssertNotNil(image)
            XCTAssertEqual(url, self.applicationURL)
            XCTAssertNil(self.defaults.object(forKey: SAAppIconController.preferenceKey))
            return true
        })
        XCTAssertTrue(try subject.select(.light, using: defaults))
        XCTAssertEqual(defaults.integer(forKey: SAAppIconController.preferenceKey), SAAppIconAppearance.light.rawValue)
        XCTAssertEqual(defaults.integer(forKey: "Appearance"), 2)
        XCTAssertEqual(defaults.data(forKey: SAPersistentAppIconController.bookmarkKey), bookmark)
    }

    func testWriteFailureDoesNotSavePreferenceOrBookmark() {
        let subject = controller(request: { $0 }, write: { _, _ in false })
        XCTAssertThrowsError(try subject.select(.light, using: defaults))
        XCTAssertNil(defaults.object(forKey: SAAppIconController.preferenceKey))
        XCTAssertNil(defaults.data(forKey: SAPersistentAppIconController.bookmarkKey))
    }

    func testAnotherApplicationCannotBeModified() {
        let subject = controller(request: { _ in URL(fileURLWithPath: "/Applications/Other.app") }, write: { _, _ in
            XCTFail("Must never write to another app")
            return true
        })
        XCTAssertThrowsError(try subject.select(.dark, using: defaults))
        XCTAssertNil(defaults.object(forKey: SAAppIconController.preferenceKey))
    }

    func testSavedGrantAvoidsAnotherPermissionPanel() throws {
        defaults.set(bookmark, forKey: SAPersistentAppIconController.bookmarkKey)
        let subject = controller(request: { _ in
            XCTFail("Existing valid access should be reused")
            return nil
        }, write: { _, _ in true })
        XCTAssertTrue(try subject.select(.dark, using: defaults))
    }

    func testSystemSelectionRemovesCustomFinderIcon() throws {
        defaults.set(bookmark, forKey: SAPersistentAppIconController.bookmarkKey)
        defaults.set(SAAppIconAppearance.light.rawValue, forKey: SAAppIconController.preferenceKey)
        var writes = 0
        let subject = controller(request: { _ in nil }, write: { image, _ in
            XCTAssertNil(image)
            writes += 1
            return true
        })
        XCTAssertTrue(try subject.select(.system, using: defaults))
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(defaults.integer(forKey: SAAppIconController.preferenceKey), 0)
    }

    func testStartupRestoresSavedIconWithoutPrompting() {
        defaults.set(bookmark, forKey: SAPersistentAppIconController.bookmarkKey)
        defaults.set(SAAppIconAppearance.light.rawValue, forKey: SAAppIconController.preferenceKey)
        var writes = 0
        let subject = controller(request: { _ in
            XCTFail("Startup must not request access")
            return nil
        }, write: { _, url in
            XCTAssertEqual(url, self.applicationURL)
            writes += 1
            return true
        })
        subject.restoreIfAuthorized(using: defaults)
        XCTAssertEqual(writes, 1)
    }

    func testStartupNeverTouchesAppMovedAwayFromCurrentInstallation() {
        defaults.set(bookmark, forKey: SAPersistentAppIconController.bookmarkKey)
        defaults.set(SAAppIconAppearance.light.rawValue, forKey: SAAppIconController.preferenceKey)
        let subject = controller(request: { _ in
            XCTFail("Startup must not request access")
            return nil
        }, resolve: { _ in URL(fileURLWithPath: "/Users/test/.Trash/Sequel Ace.app") }, write: { _, _ in
            XCTFail("Old installation must not be changed")
            return false
        })
        subject.restoreIfAuthorized(using: defaults)
    }

    func testSystemStartupPreservesUserFinderCustomization() {
        defaults.set(bookmark, forKey: SAPersistentAppIconController.bookmarkKey)
        defaults.set(0, forKey: SAAppIconController.preferenceKey)
        let subject = controller(request: { _ in nil }, write: { _, _ in
            XCTFail("System startup must not clear a Finder customization")
            return false
        })
        subject.restoreIfAuthorized(using: defaults)
    }

    func testMissingImageDoesNotRequestAccessOrChangeFinderIcon() {
        let subject = controller(imageAvailable: false, request: { _ in
            XCTFail("No need to request access when an image is missing")
            return nil
        }, write: { _, _ in
            XCTFail("A missing image must not clear the custom icon")
            return false
        })
        XCTAssertThrowsError(try subject.select(.light, using: defaults))
    }
}
