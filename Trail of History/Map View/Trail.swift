//
//  Path.swift
//  Trail of History
//
//  Created by Robert Vaessen on 10/10/17.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import CoreLocation

enum TrailLoadStatus {
    case success(Array<CLLocationCoordinate2D>)
    case error(String)
}

let tohFileName: String? = { // Name only; extension is assumed to be json
    return Bundle.main.infoDictionary?["TOH File Name"] as? String
}()

private let coordinatesPath = "TrailCoordinates"

func loadTrail(completionHandler: @escaping  (TrailLoadStatus) -> ()) {
    if let fileName = tohFileName { completionHandler(loadTrailFrom(fileName: fileName)) }
    else { loadTrailFromDatabase(completionHandler: completionHandler) }
}

func loadTrailFrom(fileName: String) -> TrailLoadStatus  {
    guard let jsonFilePath = Bundle.main.path(forResource: fileName, ofType: "json")
    else { return .error("Could not find the bundled file \(fileName).json") }

    let jsonFileUrl = URL(fileURLWithPath: jsonFilePath)
    
    do {
        let jsonData = try Data(contentsOf: jsonFileUrl)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
        
        if  let jsonData = jsonObject as? [String : Any],
            let jsonCoordinates = jsonData[coordinatesPath] as? [String : [String : Double]] {
            
            guard jsonCoordinates.count >= 2 else {
                return .error("\(fileName).json has \(jsonCoordinates.count) coordinates; there need to be at least 2.")
            }
            
            var coordinates = Array<CLLocationCoordinate2D>(repeating: CLLocationCoordinate2D(), count: jsonCoordinates.count)
            for (key, value) in jsonCoordinates {
                coordinates[Int(key)! - 1] = CLLocationCoordinate2D(latitude: value["latitude"]!, longitude: value["longitude"]!)
            }
            return .success(coordinates)
        }
        else {
            return .error("The json object does not contain the expected types and/or keys:\n\(jsonObject)")
        }
    }
    catch {
        return .error("Error reading/parsing \(jsonFilePath): \(error)")
    }
}


func loadTrailFromDatabase(completionHandler: @escaping  (TrailLoadStatus) -> ()) {

    class Loader {
        private let completionHandler: (TrailLoadStatus) -> ()
        private var observer: Firebase.Observer? = nil
        private var previousCount = 0
        private var coordinates = [CLLocationCoordinate2D]()
        
        init(completionHandler: @escaping (TrailLoadStatus) -> ()) {
            self.completionHandler = completionHandler

            observer = Firebase.Observer(path: coordinatesPath) { event, key, properties in
                self.coordinates.append(CLLocationCoordinate2D(latitude: properties["latitude"] as! Double, longitude: properties["longitude"] as! Double))
            }
        }
        
        @objc func detectCompletion(_ timer: Timer) {
            if coordinates.count == previousCount {  // If the count is the same (i.e. no new records have arrived) then we are done.
                observer?.cancel()
                timer.invalidate()
                
                if coordinates.count > 1 { completionHandler(.success(coordinates)) }
                else { completionHandler(.error("The database sent \(coordinates.count) coordinates; there need to be at least 2.")) }
            }
            else {
                previousCount = coordinates.count
            }
         }
    }

    // Firebase doesn't give us a way to obtain the count so we resort to a timer to detect that no more is coming.
    let loader = Loader(completionHandler: completionHandler)
    let timer = Timer(fireAt: Date().addingTimeInterval(1), interval: 0.25, target: loader, selector: #selector(Loader.detectCompletion(_:)), userInfo: nil, repeats: true)
    RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
}

