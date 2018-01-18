//
//  Path.swift
//  Trail of History
//
//  Created by Robert Vaessen on 10/10/17.
//  Copyright © 2017 CLT Mobile. All rights reserved.
//

import CoreLocation
import MapKit
import VerticonsToolbox

enum LoadStatus {
    case success(UserTrackingPolyline)
    case error(String)
}

func LoadPath(mapView: MKMapView) -> LoadStatus {

    let bundledPolylinesFileName = "Path"
    
    if let jsonFilePath = Bundle.main.path(forResource: bundledPolylinesFileName, ofType: "json") {
        return LoadPath(jsonFilePath: jsonFilePath, mapView: mapView)
    }

    return .error("Cannot find \(bundledPolylinesFileName).json in bundle.")
}

private func LoadPath(jsonFilePath: String, mapView: MKMapView)  -> LoadStatus {
    let jsonFileUrl = URL(fileURLWithPath: jsonFilePath)
    
    do {
        let jsonData = try Data(contentsOf: jsonFileUrl)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
        
        if  let jsonCoordinates = jsonObject as? [String : [String : Double]] {
            
            guard jsonCoordinates.count >= 2 else {
                return .error("\(jsonFilePath) has \(jsonCoordinates.count) coordinates; there need to be at least 2.")
            }
            
            var coordinates = Array<CLLocationCoordinate2D>(repeating: CLLocationCoordinate2D(), count: jsonCoordinates.count)
            for (key, value) in jsonCoordinates {
                coordinates[Int(key)! - 1] = CLLocationCoordinate2D(latitude: value["latitude"]!, longitude: value["longitude"]!)
            }
            
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.title = "Trail Of History"
            
            return .success(UserTrackingPolyline(polyline: polyline, mapView: mapView))
        }
        else {
            return .error("The json object does not contain the expected types and/or keys:\n\(jsonObject)")
        }
    }
    catch {
        return .error("Error reading/parsing \(jsonFilePath): \(error)")
    }
}

/*
enum PathEvent {
    case userOnChange(Path)
    case currentSegmentChange(Path)
}

class Path : Broadcaster<PathEvent> {

    enum LoadStatus {
        case success(Path)
        case error(String)
    }

    struct Segment : Equatable {
        static func == (lhs: Segment, rhs: Segment) -> Bool { return lhs.northern == rhs.northern && lhs.southern == rhs.southern }

        static let maxLaterlTolerence = 10.0

        let northern: CLLocation
        let southern: CLLocation
        let bearing: CLLocationDegrees // radians

        init(northern: CLLocationCoordinate2D, southern: CLLocationCoordinate2D) {
            self.northern = CLLocation(latitude: northern.latitude, longitude: northern.longitude)
            self.southern = CLLocation(latitude: southern.latitude, longitude: southern.longitude)
            bearing = toRadians(degrees: self.southern.bearing(to: self.northern))
        }
        func locationIsOn(_ testLocation: CLLocation) -> Bool {
            // Ensure that the test location's latitude is between the segment ends
            guard   testLocation.coordinate.latitude <= northern.coordinate.latitude &&
                    testLocation.coordinate.latitude >= southern.coordinate.latitude
            else { return false }

            // Determine the location along the segment whereat the latitude is equal to that of the test location.
            let latitude = testLocation.coordinate.latitude
            let deltaLat = toRadians(degrees: latitude - southern.coordinate.latitude)
            let radius = deltaLat / sin(bearing)
            let deltaLng = radius * cos(bearing)
            let longitude = southern.coordinate.longitude + deltaLng
            let segmentLocation = CLLocation(latitude: latitude, longitude: longitude)
 
            let distance = segmentLocation.yards(from: testLocation)
            return distance <= Segment.maxLaterlTolerence
        }
    }

    static func load(pathName: String) -> LoadStatus {
        return fromFile(pathName: pathName)
    }

    private static let bundledJsonFileName = "Path"
    private static func fromFile(pathName: String) -> LoadStatus {
        
        guard let jsonFilePath = Bundle.main.path(forResource: bundledJsonFileName, ofType: "json") else {
            return .error("Cannot find \(bundledJsonFileName).json in bundle.")
        }
            
        let jsonFileUrl = URL(fileURLWithPath: jsonFilePath)
        
        do {
            let jsonData = try Data(contentsOf: jsonFileUrl)
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            
            if  let jsonContainer = jsonObject as? [String : [String: Any]],
                let jsonCoordinates = jsonContainer["Path"]?[pathName] as? [String : [String : Double]] {
                
                guard jsonCoordinates.count >= 2 else {
                    return .error("\(bundledJsonFileName).json has \(jsonCoordinates.count) coordinates; there need to be at least 2.")
                }
                
                var coordinates = Array<CLLocationCoordinate2D>(repeating: CLLocationCoordinate2D(), count: jsonCoordinates.count)
                for (key, value) in jsonCoordinates {
                    coordinates[Int(key)! - 1] = CLLocationCoordinate2D(latitude: value["latitude"]!, longitude: value["longitude"]!)
                }
                coordinates.sort{ $0.latitude > $1.latitude } // North to south

                var segments = Array<Segment>(repeating: Segment(northern: CLLocationCoordinate2D(), southern: CLLocationCoordinate2D()), count: coordinates.count - 1)
                for i in 0 ... coordinates.count - 2 { segments[i] = Segment(northern: coordinates[i], southern: coordinates[i+1]) }

                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                polyline.title = pathName

                return .success(Path(polyline: polyline, segments: segments))
            }
            else {
                return .error("The json object does not contain the expected types and/or keys:\n\(jsonObject)")
            }
        }
        catch {
            return .error("Error reading/parsing \(bundledJsonFileName).json: \(error)")
        }
    }
    
    private static let northWestCornerIndex = 0
    private static let northEastCornerIndex = 1
    private static let southEastCornerIndex = 2
    private static let southWestCornerIndex = 3

    // **************************************************************

    let polyline: MKPolyline
    let segments: [Segment]

    private init(polyline: MKPolyline, segments: [Segment]) {
        self.polyline = polyline
        self.segments = segments
        super.init()

        _ = UserLocation.instance.addListener(self, handlerClassMethod: Path.userLocationEventHandler)
    }

    private var previousIsOnState = false
    private func userLocationEventHandler(event: UserLocationEvent) {
        switch event {

        case .locationUpdate(let userLocation):
            var currentSegment: Segment?
            for segment in segments { // TODO: Consider the optimization of beginning the search with the current segment
                if segment.locationIsOn(userLocation) {
                    currentSegment = segment
                    break
                }
            }

            if currentSegment != self.currentSegment {
                self.currentSegment = currentSegment
                broadcast(.currentSegmentChange(self))
            }

            if previousIsOnState != userIsOn {
                previousIsOnState = !previousIsOnState
                broadcast(.userOnChange(self))
            }
            
        default:
            return
        }
    }

    var userIsOn: Bool {
        return currentSegment != nil
    }

    private(set) var currentSegment: Segment?

    private (set) lazy var boundingPolygon: MKPolygon = {
        let coords = self.boundingCorners
        return MKPolygon(coordinates: coords, count: coords.count)
    }()

    private (set) lazy var  boundingRegion: MKCoordinateRegion = {
        let corners = self.boundingCorners
        let span = MKCoordinateSpanMake(corners[Path.northWestCornerIndex].latitude - corners[Path.southWestCornerIndex].latitude,
                                        corners[Path.northEastCornerIndex].longitude - corners[Path.northWestCornerIndex].longitude)
        return MKCoordinateRegionMake(self.midCoordinate, span)
        
    }()

    private(set) lazy var midCoordinate: CLLocationCoordinate2D = {
        let origin = self.polyline.boundingMapRect.origin
        let size = self.polyline.boundingMapRect.size
        return MKCoordinateForMapPoint(MKMapPoint(x: origin.x + size.width/2, y: origin.y + size.height/2))
     }()

    private lazy var boundingCorners: [CLLocationCoordinate2D] = {
        let rect = self.polyline.boundingMapRect
        let margin = 50.0
        let northWestCorner = MKMapPoint(x: rect.origin.x - margin, y: rect.origin.y - margin)
        let width = rect.size.width + 2 * margin
        let height = rect.size.height + 2 * margin

        var coords = Array<CLLocationCoordinate2D>(repeating: CLLocationCoordinate2D(), count: 4)
        coords[Path.northWestCornerIndex] = MKCoordinateForMapPoint(northWestCorner)
        coords[Path.northEastCornerIndex] = MKCoordinateForMapPoint(MKMapPoint(x: northWestCorner.x + width, y: northWestCorner.y))
        coords[Path.southEastCornerIndex] = MKCoordinateForMapPoint(MKMapPoint(x: northWestCorner.x + width, y: northWestCorner.y + height))
        coords[Path.southWestCornerIndex] = MKCoordinateForMapPoint(MKMapPoint(x: northWestCorner.x, y: northWestCorner.y + height))
        return coords
    }()
}
*/
