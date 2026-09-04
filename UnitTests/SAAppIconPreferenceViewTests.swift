import XCTest
import AppKit

final class SAAppIconPreferenceViewTests: XCTestCase {
    func testPreferencesNibCanFindHostingViewByItsClassName() {
        XCTAssertEqual(NSStringFromClass(SAAppIconPreferenceHostingView.self), "SAAppIconPreferenceHostingView")
        XCTAssertNotNil(NSClassFromString("SAAppIconPreferenceHostingView"))
    }

    func testHostingViewContributesHeightToGeneralPreferences() {
        _ = NSApplication.shared
        let view = SAAppIconPreferenceHostingView(frame: NSRect(x: 0, y: 0, width: 656, height: 60))
        view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(view.fittingSize.height, 30)
    }
}
