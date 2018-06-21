//
//  PointOfInterest.swift
//  Trail of History
//
//  Created by Robert Vaessen on 12/23/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation
import VerticonsToolbox

enum PoiLoadStatus {
    case success
    case error(String)
}


final class PointOfInterest : Equatable, Encoding {

    // **********************************************************************************************************************
    //                                                  Public
    // **********************************************************************************************************************

    static func == (lhs: PointOfInterest, rhs: PointOfInterest) -> Bool { return lhs.name == rhs.name }

    typealias ListenerToken = Any

    private class Token {
        var observer: Firebase.TypeObserver<PointOfInterest>?
        init(observer: Firebase.TypeObserver<PointOfInterest>?) { self.observer = observer }
    }

    private static let poiPath = "PointsOfInterest"

    // Points of Interest are obtained via a listener. Listeners will receive the
    // currently existing POIs and will be informed of additions, updates, or removals.
    // Currently (03/22/18) there are two scenarios:
    //      1)  The POIs are being obtained from a bundled file. In this case the listener will
    //          be called for each POI  before the addListener method returns and there will be
    //          no future invocations.
    //      2)  The POIs are being obtained from a database. In this case the listener will
    //          called in the future, asynchronously, as the POIs arive from the database.
    //          If the database is subsequently updated then the listener will be called again
    // Each listener receives its own copies of the POIs
    static func addListener(_ listener: @escaping Firebase.TypeObserver<PointOfInterest>.TypeListener) -> ListenerToken {

        var observer: Firebase.TypeObserver<PointOfInterest>? = nil
        if let fileName = tohFileName {
            if case .error(let message) = loadFrom(fileName: fileName, listener: listener) {
                alertUser(title: "Cannot Load Points of Interest", body: message)
            }
        }
        else {
            observer = Firebase.TypeObserver(path: poiPath, with: listener)
        }
        return Token(observer: observer)
    }
    
    static func loadFrom(fileName: String, listener: @escaping Firebase.TypeObserver<PointOfInterest>.TypeListener) -> PoiLoadStatus {
        guard let jsonFilePath = Bundle.main.path(forResource: fileName, ofType: "json")
            else { return .error("Could not find the bundled file \(fileName).json") }
        
        let jsonFileUrl = URL(fileURLWithPath: jsonFilePath)
        
        do {
            let jsonData = try Data(contentsOf: jsonFileUrl)
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            
            if  let jsonData = jsonObject as? [String : Any],
                let pointsOfInterest = jsonData[poiPath] as? [String : Properties] {
                for (key, properties) in pointsOfInterest {
                    if let poi = PointOfInterest(properties) { poi.finish(event: .added, key: key, listener: listener) }
                    else { print("Invalid POI properties: \(properties)") }
                }
            }
            else {
                return .error("The json object does not contain the expected types and/or keys:\n\(jsonObject)")
            }
        }
        catch {
            return .error("Cannot read/parse \(fileName): \(error)")
        }
        
        return .success
    }

    static func removeListener(token: ListenerToken) -> Bool {
        if let token = token as? Token {
            token.observer?.cancel()
            token.observer = nil
            return true
        }
        return false
    }

    var distanceToUser: Int? {
        guard let userLocation = UserLocation.instance.currentLocation else { return nil }

        return Int(round(self.location.yards(from: userLocation)))
    }
    
    var distanceToUserText: String {
        guard let distance = distanceToUser else { return "<unknown>" }
        
        return "\(distance) yds"
    }
    
    // Return the heading that would take the user to the point of interest.
    var poiHeading: Double? {
        return UserLocation.instance.currentLocation?.bearing(to: self.location)
    }
    
    // Return the positive, clockwise angle (0 -> 359.999) from the user's heading to the poi's heading.
    var angleWithUserHeading: Double? {
        if  let userHeading = UserLocation.instance.currentBearing, let poiHeading = self.poiHeading {
            let delta = abs(poiHeading - userHeading)
            return userHeading > poiHeading ? 360 - delta : delta
        }
        return nil
    }
    
    // **********************************************************************************************************************
    //                                              Internal
    // **********************************************************************************************************************

    private static let latitudeKey = "latitude"
    private static let longitudeKey = "longitude"
    private static let descriptionKey = "description"
    private static let imageUrlKey = "imageUrl"
    private static let movieUrlKey = "movieUrl"
    private static let meckncGovUrlKey = "meckncGovUrl"

    var name: String
    let description: String
    let location: CLLocation
    let movieUrl: URL?
    let meckncGovUrl: URL?
    var image: UIImage!

    private let imageUrl: URL

    public init?(_ properties: Properties?) {
        guard
            let properties = properties,
            let latitude = properties[PointOfInterest.latitudeKey] as? Double,
            let longitude = properties[PointOfInterest.longitudeKey] as? Double,
            let description = properties[PointOfInterest.descriptionKey] as? String,
            let imageUrlString = properties[PointOfInterest.imageUrlKey] as? String,
            let imageUrl = URL(string: imageUrlString)
        else { return nil }

        location = CLLocation(latitude: latitude, longitude: longitude)
        self.description = description
        self.imageUrl =  imageUrl
        if let url = properties[PointOfInterest.movieUrlKey] as? String { self.movieUrl = URL(string: url) } else { self.movieUrl = nil }
        if let url = properties[PointOfInterest.meckncGovUrlKey] as? String { self.meckncGovUrl = URL(string: url) } else { self.meckncGovUrl = nil }

        self.name = "<unknown>" // The name is provided by the record's key, see the finish() method.
    }
    
    func finish(event: Firebase.TypeObserver<PointOfInterest>.Event, key: Firebase.TypeObserver<PointOfInterest>.Key, listener: @escaping Firebase.TypeObserver<PointOfInterest>.TypeListener) {

        name = key

        let imageUrlKey = "url:" + name
        let imageDataKey = "image:" + name
        
        enum ImageRetrievalResult {
            case success(Data)
            case failure(String)
        }
        
        func finish(result: ImageRetrievalResult) {
            var image: UIImage!
            
            switch result {
            case .success(let imageData):
                image = UIImage(data: imageData)
                if image != nil {
                    UserDefaults.standard.set(imageUrl, forKey: imageUrlKey)
                    UserDefaults.standard.set(imageData, forKey: imageDataKey)
                }
                else {
                    image = UIImage.createFailureIndication(ofSize: CGSize(width: 1920, height: 1080), withText: "The image data is corrupt")
                }
            case .failure(let errorText):
                image = UIImage.createFailureIndication(ofSize: CGSize(width: 1920, height: 1080), withText: errorText)
            }

            self.image = image

            DispatchQueue.main.async { listener(event, key, self) }
        }
        
        DispatchQueue.global().async {
            // If the image URL has not changed then use the locally stored image. Else download the image from the remote database
            if let prevImageUrl = UserDefaults.standard.url(forKey: imageUrlKey), prevImageUrl == self.imageUrl {
                guard let imageData = UserDefaults.standard.data(forKey: imageDataKey) else {
                    fatalError("User defaults has an image url but no image data???")
                }
                
                finish(result: ImageRetrievalResult.success(imageData))
            }
            else {
                let session = URLSession(configuration: .default)
                let imageDownloadTask = session.dataTask(with: self.imageUrl) { (data, response, error) in
                    if let error = error {
                        finish(result: ImageRetrievalResult.failure("URLSession data task error: \(error)"))
                    }
                    else {
                        if let response = response as? HTTPURLResponse {
                            if response.statusCode == 200 {
                                if let imageData = data {
                                    finish(result: ImageRetrievalResult.success(imageData))
                                }
                                else {
                                    finish(result: ImageRetrievalResult.failure("Image data is nil"))
                                }
                            }
                            else {
                                finish(result: ImageRetrievalResult.failure("HTTP response error: \(response.statusCode)"))
                            }
                        }
                        else {
                            finish(result: ImageRetrievalResult.failure("Response type is \(type(of: response)); expected HTTPURLResponse"))
                        }
                    }
                }
                imageDownloadTask.resume()
            }
        }
    }
    
    public func encode() -> Properties {
        fatalError("Encode is not implememnted") // We don't need to encode points of interest; the app does not update the database.
    }
}
