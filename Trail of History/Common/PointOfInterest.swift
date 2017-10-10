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
class PointOfInterest {

    // **********************************************************************************************************************
    //                                                  API
    // **********************************************************************************************************************

    enum Event {
        case added
        case updated
        case removed
    }
    
    typealias Observer = (PointOfInterest, Event) -> Void
    typealias ObserverToken = Any

    // Points of Interest are obtained via observers. Observwers will receive the
    // currently existing POIs and will be informed of additions, updates, or removals.
    static func addObserver(_ observer: @escaping Observer, dispatchQueue: DispatchQueue) -> ObserverToken {
        return Database.ObserverToken(observer: Database.Observer(observer: observer, dispatchQueue: dispatchQueue))
    }
    static func removeObserver(token: ObserverToken) -> Bool {
        if let token = token as? Database.ObserverToken {
            token.observer.cancel()
            token.observer = nil
            return true
        }
        return false
    }

    let name: String
    let description: String
    let location: CLLocation
    let image: UIImage
    let id: String
    let movieUrl: URL?

    var distanceToUser: String {
        if let userLocation = UserLocation.instance.currentLocation {
            return "\(Int(round(self.location.yards(from: userLocation)))) yds"
        }
        return "<unknown>"
    }
    
    // Return the heading that would take the user to the point of interest.
    var poiHeading: Double? {
        return UserLocation.instance.currentLocation?.bearing(to: self.location)
    }
    
    // Return the angle between the user's actual heading and the heading that would take him/her to the point of interest.
    // If the user's heading would take him/her south of the poi then the angle will be positive, else it will be negative.
    var angleWithUserHeading: Double? {
        if  let userHeading = UserLocation.instance.currentBearing, let poiHeading = self.poiHeading {
            return userHeading - poiHeading
        }
        return nil
    }
    
    // **********************************************************************************************************************
    //                                              Internal
    // **********************************************************************************************************************

    private weak var observer: Database.Observer?

    private init(id: String, name: String, latitude: Double, longitude: Double, description: String, image: UIImage, movieUrl: URL?, observer: Database.Observer) {
        self.id = id
        self.name = name
        self.description = description
        self.image = image
        self.movieUrl = movieUrl
        
        location = CLLocation(latitude: latitude, longitude: longitude)
        
        self.observer = observer // Inform the observer of location updates
        _ = UserLocation.instance.addListener(self, handlerClassMethod: PointOfInterest.userLocationEventHandler) // Listen to location updates
    }
    
    // When updates are received from the database the observers will be sent a new version of a Point of Interest.
    // If the observer releases the previous version that it had received then the UserLocation will stop sendimg
    // location events to that previous instance. This is due to the fact that Broadcasters (which the UserLocation
    // is) store their listener references weakly.
    private func userLocationEventHandler(event: UserLocationEvent) {
        switch event {
        case .locationUpdate:
            break
            
        case .headingUpdate:
            break
            
        default:
            return
        }

        if let observer = self.observer {
            observer.notify(poi: self, event: .updated)
        }
    }

    // **********************************************************************************************************************

    private class Database {

        static let connection = Connection()

        class Connection {
            
            private static let magicPath = ".info/connected"
            private static let alertTitle = "Trail of History"
            
            private enum ConnectionState {
                case initialCall
                case neverConnected
                case connected
                case disconnected
            }
            
            private let connectedRef: FIRDatabaseReference
            private var connectionState: ConnectionState = .initialCall
            
            init() {
                // At startup time the connection observer will be called twice. The first time with a value of false.
                // The second time with a value of true(false) according to whether everything [Device is connected to the
                // network, Firebase server is up] is(is not) up and running. Thereafter the observer will be called
                // once whenever the connection state changes.
                
                connectedRef = FIRDatabase.database().reference(withPath: Connection.magicPath)
                connectedRef.observe(.value, with: {
                    var isConnected = false
                    if let connected = $0.value as? Bool, connected { isConnected = true }
                    
                    switch self.connectionState {
                        
                    case .initialCall:
                        assert(!isConnected, "Our assumption that the observer's initial call will be with a value of false has been violated!")
                        self.connectionState = .neverConnected
                        
                    case .neverConnected:
                        if isConnected {
                            self.connectionState = .connected
                        } else {
                            //TODO: It would be nice to only bother the user with an alert if we cannot connect and there is no locally cached data.
                            // But when I tried to query Firebase under conditions of no connection and no local data my callback did not execute?
                            self.connectionState = .disconnected
                            alertUser(title: Connection.alertTitle, body: "A connection to the internet cannot be established. Trail of History will use the points of interest information that was obtained during the previous, successful internet connection. If you have never used the application while being connected to the internet then there will not be any information.")
                        }
                        
                    case .connected:
                        assert(!isConnected, "We are already connected. Why are we being called again with a value of true?")
                        if !isConnected {
                            self.connectionState = .disconnected
                            //alertUser(title: self.alertTitle, body: "The connection to the database has been lost. The app will continue to work with the Points of Interest that have already been downloaded. You will not receive updates (which, anyway, are rare).")
                        }
                        
                    case .disconnected:
                        assert(isConnected, "We are already disconnected. Why are we being called again with a value of false?")
                        if isConnected {
                            self.connectionState = .connected
                            //alertUser(title: self.alertTitle, body: "The connection to the database has been established.")
                        }
                    }
                })
            }
        }
        
        class Observer {
            
            private static let path = "points-of-interest"
            
            private var observer: PointOfInterest.Observer
            private var dispatchQueue: DispatchQueue
            private var reference: FIRDatabaseReference?
            private var childAddedObservationId: UInt = 0
            private var childChangedObservationId: UInt = 0
            private var childRemovedObservationId: UInt = 0
            
            fileprivate init(observer: @escaping PointOfInterest.Observer, dispatchQueue: DispatchQueue) {
                self.observer = observer
                self.dispatchQueue = dispatchQueue
                
                // Note: Itried using a single Observer of the event type .value but each event sent all of the poi records???
                
                reference = FIRDatabase.database().reference(withPath: Observer.path)
                childAddedObservationId = reference!.observe(.childAdded,   with: { self.eventHandler(properties: $0.value as! [String: Any], event: .added) })
                childChangedObservationId = reference!.observe(.childChanged, with: { self.eventHandler(properties: $0.value as! [String: Any], event: .updated) })
                childRemovedObservationId = reference!.observe(.childRemoved, with: { self.eventHandler(properties: $0.value as! [String: Any], event: .removed) })
            }
            
            deinit {
                cancel()
            }
            
            fileprivate func cancel() {
                if let ref = reference {
                    ref.removeObserver(withHandle: childAddedObservationId)
                    ref.removeObserver(withHandle: childChangedObservationId)
                    ref.removeObserver(withHandle: childRemovedObservationId)
                    reference = nil
                }
            }
            
            private func eventHandler(properties: [String: Any], event: Event) {
                guard
                    let id = properties["uid"] as? String,
                    let name = properties["name"] as? String,
                    let latitude = properties["latitude"] as? Double,
                    let longitude = properties["longitude"] as? Double,
                    let description = properties["description"] as? String,
                    let imageUrlString = properties["imageUrl"] as? String,
                    let imageUrl = URL(string: imageUrlString)
                else {
                    print("Invalid POI data: \(properties)")
                    return
                }

                var movieUrl: URL? = nil
                if let movieUrlString = properties["movieUrl"] as? String {
                    movieUrl = URL(string: movieUrlString)
                }

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

                    let poi = PointOfInterest(id: id, name: name, latitude: latitude, longitude: longitude, description: description, image: image, movieUrl: movieUrl, observer: self)
                    self.notify(poi: poi, event: event)
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
            
            fileprivate func notify(poi: PointOfInterest, event: Event) {
                dispatchQueue.async { self.observer(poi, event) }
            }
        }

        class ObserverToken {
            var observer: Database.Observer!
            init(observer: Database.Observer) { self.observer = observer }
        }
    }
}
