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

// TODO: More testing of realtime response to database updates.
final class PointOfInterest : Equatable, Encoding {

    // **********************************************************************************************************************
    //                                                  Public
    // **********************************************************************************************************************

    static func == (lhs: PointOfInterest, rhs: PointOfInterest) -> Bool { return lhs.id == rhs.id }

    typealias FirebaseObserver = Firebase.DataObserver<PointOfInterest>
    typealias FirebaseObserverToken = Any

    // Points of Interest are obtained via observers. Observwers will receive the
    // currently existing POIs and will be informed of additions, updates, or removals.
    private class Token {
        var observer: FirebaseObserver!
        init(observer: FirebaseObserver) { self.observer = observer }
    }

    static func addObserver(_ observer: @escaping FirebaseObserver.DataObserver, dispatchQueue: DispatchQueue) -> FirebaseObserverToken {
        return Token(observer: Firebase.DataObserver(path: "PointsOfInterest", with: observer, dispatchingTo: dispatchQueue))
    }

    static func removeObserver(token: FirebaseObserverToken) -> Bool {
        if let token = token as? Token {
            token.observer.cancel()
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

    private static let idKey = "uid"
    private static let nameKey = "name"
    private static let latitudeKey = "latitude"
    private static let longitudeKey = "longitude"
    private static let descriptionKey = "description"
    private static let imageUrlKey = "imageUrl"
    private static let movieUrlKey = "movieUrl"
    private static let meckncGovUrlKey = "meckncGovUrl"

    let id: String
    let name: String
    let description: String
    let location: CLLocation
    let movieUrl: URL?
    let meckncGovUrl: URL?
    var image: UIImage!

    private let imageUrl: URL

    // TODO: How are the POIs views updating there distance to user?
    //private weak var observer: Firebase.Observer?
    //self.observer = observer // Inform the observer of location updates

    public init?(_ properties: Properties?) {
        guard
            let properties = properties,
            let id = properties[PointOfInterest.idKey] as? String,
            let name = properties[PointOfInterest.nameKey] as? String,
            let latitude = properties[PointOfInterest.latitudeKey] as? Double,
            let longitude = properties[PointOfInterest.longitudeKey] as? Double,
            let description = properties[PointOfInterest.descriptionKey] as? String,
            let imageUrlString = properties[PointOfInterest.imageUrlKey] as? String,
            let imageUrl = URL(string: imageUrlString)
        else { return nil }

        self.id = id
        self.name = name
        self.description = description
        self.imageUrl =  imageUrl
        if let url = properties[PointOfInterest.movieUrlKey] as? String { self.movieUrl = URL(string: url) } else { self.movieUrl = nil }
        if let url = properties[PointOfInterest.meckncGovUrlKey] as? String { self.meckncGovUrl = URL(string: url) } else { self.meckncGovUrl = nil }

        location = CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func finish(event: FirebaseObserver.Event, key: FirebaseObserver.Key, observer: @escaping FirebaseObserver.DataObserver) {

        let imageUrlKey = "url:" + id
        let imageDataKey = "image:" + id
        
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
            observer(event, key, self)
        }
        
        
        // If the image URL has not changed then use the locally stored image. Else download the image from the remote database
        if let prevImageUrl = UserDefaults.standard.url(forKey: imageUrlKey), prevImageUrl == imageUrl {
            guard let imageData = UserDefaults.standard.data(forKey: imageDataKey) else {
                fatalError("User defaults has an image url but no image data???")
            }
            
            finish(result: ImageRetrievalResult.success(imageData))
        }
        else {
            let session = URLSession(configuration: .default)
            let imageDownloadTask = session.dataTask(with: imageUrl) { (data, response, error) in
                
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
    
    public func encode() -> Properties {
        fatalError("Encode is not implememnted") // We don't need to encode points of interest; the app does not update the database.
    }
}
