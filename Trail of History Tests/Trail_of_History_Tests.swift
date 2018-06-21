//
//  Trail_of_History_Tests.swift
//  Trail of History Tests
//
//  Created by Robert Vaessen on 3/14/18.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import XCTest
import VerticonsToolbox
import CoreLocation

@testable import Trail_of_History

class Trail_of_History_Tests: XCTestCase {
    
    var mapVC: MapViewController?
    var listVC: ListViewController?
    var pageVC: PageViewController?

    var locationListener: ((CLLocation) -> ())?
    var locationListenerToken: ListenerManagement?

    var trail: [CLLocationCoordinate2D]!
    var pointsOfInterest: [PointOfInterest]!

    override func setUp() {
        super.setUp()
        
        pageVC = UIApplication.shared.keyWindow?.rootViewController?.childViewControllers[0] as? PageViewController
        mapVC = pageVC?.mapViewController
        XCTAssertNotNil(mapVC)
        listVC = pageVC?.listViewController
        XCTAssertNotNil(listVC)

        trail = nil
        pointsOfInterest = nil
        loadData()
  
        locationListenerToken = UserLocation.instance.addListener(self, handlerClassMethod: Trail_of_History_Tests.userLocationEventHandler)
    }

    private func loadData() {

        let trailLoaded = expectation(description: "The trail coordinates were successfully loaded")

        loadTrail() {
            switch $0 {
            case .success(let coordinates): self.trail = coordinates
            case .error(let message): XCTFail(message)
            }
            trailLoaded.fulfill()
        }


        let pointsOfInterestLoaded = expectation(description: "The points of interest were successfully loaded")

        pointsOfInterest = [PointOfInterest]()
        func poiListener(event: Firebase.Observer.Event, key: Firebase.Observer.Key, poi: PointOfInterest) {
            switch event {
            case .added: pointsOfInterest.append(poi)
            case .updated: break
            case .removed: break
            }
        }
        let listenerToken = PointOfInterest.addListener(poiListener)

        var lastPoiCount = 0
        func hasPoiLoadingCompleted() -> Bool {
            let completed = lastPoiCount == pointsOfInterest.count // If the count has not changed then we're done
            lastPoiCount = pointsOfInterest.count
            if  completed { pointsOfInterestLoaded.fulfill() }
            return completed
        }
        check(condition: hasPoiLoadingCompleted, every: 0.5, withInitialDelay: 2.0)


        waitForExpectations(timeout: 30, handler: nil)

        _ = PointOfInterest.removeListener(token: listenerToken)

        if trail == nil || trail.count == 0 { XCTFail("The trail coordinates could not be loaded") }
        if pointsOfInterest.count < 1 { XCTFail("The points of interest could not be loaded") }

        var report = "The validation data was successfully loaded:\n\tThe trail has \(trail.count) coordinats\n\tThe points of interest are:\n"
        for poi in pointsOfInterest { report.append("\t\t\(poi.name)\n") }
        print(report)

    }

    override func tearDown() {
        locationListenerToken?.removeListener()
        super.tearDown()
    }

    // ******************************************************************************************************************

    func testMapView() {
        switchToMapView()
        XCTAssertTrue(mapVC!.poiAnnotations.count == pointsOfInterest.count, "The map view has \(mapVC!.poiAnnotations.count) points of interest, expected \(pointsOfInterest.count)")
    }

    func testListView() {
        pageVC!.switchPages(sender: mapVC!)
    }

    func testTrailTraversal() {
        switchToMapView()

        var counter = 0
        locationListener = { (location: CLLocation) -> () in counter += 1 }
        let trailTraversalCompleted = expectation(description: "The trail traversal has completed")
        func hasTrailTraversalCompleted() -> Bool {
            fputs(".", stdout)
            let completed = counter > trail.count
            if completed { trailTraversalCompleted.fulfill() }
            return completed
        }
        check(condition: hasTrailTraversalCompleted, every: 0.5, withInitialDelay: 2.0)
        print("Please initiate location simulation\n")
        waitForExpectations(timeout: 200, handler: nil)
        locationListener = nil
    }
    
    // ******************************************************************************************************************

    private func check(condition: () -> Bool, every: TimeInterval, withInitialDelay delay: TimeInterval) {
        let timer = Timer(fireAt: Date(timeIntervalSinceNow: delay), interval: every, target: self, selector: #selector(checkCondition), userInfo: condition, repeats: true)
        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
    }

    @objc func checkCondition(_ timer: Timer) {
        let condition = timer.userInfo as! () -> Bool
        if condition() { timer.invalidate() }
    }

    private func userLocationEventHandler(event: UserLocationEvent) {
        switch event {

        case .locationUpdate(let location):
            if let listener = locationListener { listener(location) }

        default:
            break
        }
    }
    
    private func switchToMapView() {
        pageVC!.switchPages(sender: listVC!)
        
        let mapViewHasFinishedLoading = expectation(description: "The map view has loaded all of its data")
        func mapViewIsReady() -> Bool {
            let ready = !mapVC!.isBusy
            if  ready { mapViewHasFinishedLoading.fulfill() }
            return ready
        }
        check(condition: mapViewIsReady, every: 0.5, withInitialDelay: 2.0)
        waitForExpectations(timeout: 20, handler: nil)
    }
}

