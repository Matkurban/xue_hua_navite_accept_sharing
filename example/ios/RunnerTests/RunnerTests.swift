import Flutter
import UIKit
import XCTest

@testable import xue_hua_navite_accept_sharing

class RunnerTests: XCTestCase {

  func testGetAndClearInitialSharing() {
    let plugin = XueHuaNaviteAcceptSharingPlugin()
    plugin.initialPayload = [
      "items": [
        [
          "type": "text",
          "content": "Shared from iOS test",
          "mimeType": "text/plain"
        ]
      ],
      "text": "Shared from iOS test"
    ]

    let getCall = FlutterMethodCall(methodName: "getInitialSharing", arguments: nil)
    let getExpectation = expectation(description: "getInitialSharing returns initial payload")
    plugin.handle(getCall) { result in
      let dict = result as? [String: Any?]
      XCTAssertNotNil(dict)
      XCTAssertEqual(dict?["text"] as? String, "Shared from iOS test")
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
