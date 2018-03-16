//
//  Trail_of_History_Tests.swift
//  Trail of History Tests
//
//  Created by Robert Vaessen on 3/14/18.
//  Copyright © 2018 rvaessen.com. All rights reserved.
//

import XCTest
import VerticonsToolbox

class Trail_of_History_Tests: XCTestCase {
    
    var token: ListenerManagement?
    var trailTraversalCompleted: XCTestExpectation?
    var positionUpdatesCounter = 0

    override func setUp() {
        super.setUp()
        token = UserLocation.instance.addListener(self, handlerClassMethod: Trail_of_History_Tests.userLocationEventHandler)
    }
    
    override func tearDown() {
        token?.removeListener()
        super.tearDown()
    }
    
    func testTrailTraversal() {
        trailTraversalCompleted = expectation(description: "The trail traversal completed")
        waitForExpectations(timeout: 200, handler: nil)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    private func userLocationEventHandler(event: UserLocationEvent) {
        switch event {

        case .locationUpdate(let location):
            print("Test \(positionUpdatesCounter) - lat \(location.coordinate.latitude). lon \(location.coordinate.longitude)")
            positionUpdatesCounter += 1
            if (positionUpdatesCounter == 187) { trailTraversalCompleted?.fulfill() }

        default:
            break
        }
    }

}
