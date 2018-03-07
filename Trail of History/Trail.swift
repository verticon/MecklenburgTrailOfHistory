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

private let coordinatesPath = "TrailCoordinates"

func LoadTrail(mapView: MKMapView, completionHandler: @escaping  (LoadStatus) -> ()) {
    
    if let jsonFilePath = Bundle.main.path(forResource: tohFileName, ofType: "json") {
        FromFile(mapView: mapView, completionHandler: completionHandler, jsonFilePath: jsonFilePath)
    }
    else {
        FromDatabase(mapView: mapView, completionHandler: completionHandler)
    }
}

private func FromFile(mapView: MKMapView, completionHandler: (LoadStatus) -> (), jsonFilePath: String) {
    let jsonFileUrl = URL(fileURLWithPath: jsonFilePath)
    
    do {
        let jsonData = try Data(contentsOf: jsonFileUrl)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
        
        if  let jsonData = jsonObject as? [String : Any],
            let jsonCoordinates = jsonData[coordinatesPath] as? [String : [String : Double]] {

            guard jsonCoordinates.count >= 2 else {
                completionHandler(.error("\(jsonFilePath) has \(jsonCoordinates.count) coordinates; there need to be at least 2."))
                return
            }
            
            var coordinates = Array<CLLocationCoordinate2D>(repeating: CLLocationCoordinate2D(), count: jsonCoordinates.count)
            for (key, value) in jsonCoordinates {
                coordinates[Int(key)! - 1] = CLLocationCoordinate2D(latitude: value["latitude"]!, longitude: value["longitude"]!)
            }
            print("Trail: loaded \(coordinates.count) coordinates from \(jsonFilePath)")
            
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.title = tohFileName
            
            completionHandler(.success(UserTrackingPolyline(polyline: polyline, mapView: mapView)))
        }
        else {
            completionHandler(.error("The json object does not contain the expected types and/or keys:\n\(jsonObject)"))
        }
    }
    catch {
        completionHandler(.error("Error reading/parsing \(jsonFilePath): \(error)"))
    }
}

private func FromDatabase(mapView: MKMapView, completionHandler: @escaping  (LoadStatus) -> ()) {

    class Loader {
        private let mapView: MKMapView
        private let completionHandler: (LoadStatus) -> ()
        private var observer: Firebase.Observer? = nil
        private var previousCount = 0
        private var coordinates = [CLLocationCoordinate2D]()
        
        init(mapView: MKMapView, completionHandler: @escaping (LoadStatus) -> ()) {
            self.mapView = mapView
            self.completionHandler = completionHandler

            observer = Firebase.Observer(path: coordinatesPath) { event, key, properties in
                self.coordinates.append(CLLocationCoordinate2D(latitude: properties["latitude"] as! Double, longitude: properties["longitude"] as! Double))
            }
        }
        
        @objc func detectCompletion(_ timer: Timer) {
            guard coordinates.count == previousCount else { previousCount = coordinates.count; return }
           
            // We're done
            observer?.cancel()
            timer.invalidate()
            
            if coordinates.count > 1 {
                print("Trail: loaded \(coordinates.count) coordinates from the database.")
               let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                polyline.title = "Trail Of History"
                completionHandler(.success(UserTrackingPolyline(polyline: polyline, mapView: mapView)))
            }
            else {
                completionHandler(.error("The database sent \(coordinates.count) coordinates; there need to be at least 2."))
            }
        }
    }

    // Firebase doesn't give us a way to obtain the count so we resort to a timer to detect that no more is coming.
    let loader = Loader(mapView: mapView, completionHandler: completionHandler)
    let timer = Timer(timeInterval: 0.25, target: loader, selector: #selector(Loader.detectCompletion(_:)), userInfo: nil, repeats: true)
    RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
}

