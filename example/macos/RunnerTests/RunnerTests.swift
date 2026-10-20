import Cocoa
import FlutterMacOS
import XCTest

@testable import xue_hua_navite_accept_sharing

class RunnerTests: XCTestCase {

  func testGetAndClearInitialSharing() {
    let plugin = XueHuaNaviteAcceptSharingPlugin()
    plugin.initialPayload = [
      "items": [
        [
          "type": "url",
          "content": "https://flutter.dev",
          "mimeType": "text/uri-list"
        ]
      ],
      "text": "https://flutter.dev"
    ]

    let getCall = FlutterMethodCall(methodName: "getInitialSharing", arguments: nil)
    let getExpectation = expectation(description: "getInitialSharing returns initial payload")
    plugin.handle(getCall) { result in
      let dict = result as? [String: Any?]
      XCTAssertNotNil(dict)
      XCTAssertEqual(dict?["text"] as? String, "https://flutter.dev")
      getExpectation.fulfill()
    }

    let clearCall = FlutterMethodCall(methodName: "clearInitialSharing", arguments: nil)
    let clearExpectation = expectation(description: "clearInitialSharing clears payload")
    plugin.handle(clearCall) { _ in
      XCTAssertNil(plugin.initialPayload)
      clearExpectation.fulfill()
    }

    waitForExpectations(timeout: 1)
  }

}
