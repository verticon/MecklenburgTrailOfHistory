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

enum PathEvent {
    case userOnChange(Path)
}

class Path : Broadcaster<PathEvent> {

    enum LoadStatus {
        case success(Path)
        case error(String)
    }

    static func load(name: String) -> LoadStatus {
        return fromFile(name: name)
    }

    private static func fromFile(name: String) -> LoadStatus {
        
        guard let jsonFilePath = Bundle.main.path(forResource: name, ofType: "json") else {
            return .error("Cannot find \(name).json in bundle.")
        }
            
        let jsonFileUrl = URL(fileURLWithPath: jsonFilePath)
        
        do {
            let jsonData = try Data(contentsOf: jsonFileUrl)
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            
            if let container = jsonObject as? [String : Any],
               let coordinates = container[name] as? [String : [String : Any]] {
                
                var path = Array<CLLocationCoordinate2D>(repeating: CLLocationCoordinate2D(), count: coordinates.count)
                
                for (key, value) in coordinates {
                    let index = Int(key)! - 1
                    let latitude = value["latitude"] as! Double
                    let longitude = value["longitude"] as! Double
                    path[index] = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                }
                
                let polyline = MKPolyline(coordinates: path, count: path.count)
                polyline.title = name

                return .success(Path(polyline: polyline))
            }
            else {
                return .error("The json object does not contain the expected types/keys:\n\(jsonObject)")
            }
        }
        catch {
            return .error("Error reading/parsing \(name).json: \(error)")
        }
    }
    
    private static let northWestCornerIndex = 0
    private static let northEastCornerIndex = 1
    private static let southEastCornerIndex = 2
    private static let southWestCornerIndex = 3

    // **************************************************************

    let polyline: MKPolyline
    private var previousIsOnState = false


    private init(polyline: MKPolyline) {
        self.polyline = polyline
        super.init()

        previousIsOnState = userIsOn
        _ = UserLocation.instance.addListener(self, handlerClassMethod: Path.userLocationEventHandler)
    }

    private func userLocationEventHandler(event: UserLocationEvent) {
        switch event {
        case .locationUpdate:
            if previousIsOnState != userIsOn {
                previousIsOnState = !previousIsOnState
                broadcast(.userOnChange(self))
            }
            break
            
        default:
            return
        }
    }

    // TODO: Find a good way to detect that the user is on the trail
    var userIsOn: Bool {
        guard let coord = UserLocation.instance.currentLocation?.coordinate else { return false }
        return boundingRegion.contains(coordinate: coord)
    }

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
        let origin = self.polyline.boundingMapRect.origin
        let size = self.polyline.boundingMapRect.size
        var coords = Array<CLLocationCoordinate2D>(repeating: CLLocationCoordinate2D(), count: 4)
        coords[Path.northWestCornerIndex] = MKCoordinateForMapPoint(origin)
        coords[Path.northEastCornerIndex] = MKCoordinateForMapPoint(MKMapPoint(x: origin.x + size.width, y: origin.y))
        coords[Path.southEastCornerIndex] = MKCoordinateForMapPoint(MKMapPoint(x: origin.x + size.width, y: origin.y + size.height))
        coords[Path.southWestCornerIndex] = MKCoordinateForMapPoint(MKMapPoint(x: origin.x, y: origin.y + size.height))
        return coords
    }()
}
