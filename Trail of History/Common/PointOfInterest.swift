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

class PointOfInterest {

    enum Event {
        case added
        case updated
        case removed
    }
    
    typealias Token = Any

    typealias Listener = (PointOfInterest, Event) -> Void
    
    static func registerListener(_ listener: @escaping Listener, dispatchQueue: DispatchQueue) -> Token {
        return ListenerToken(observer: Database.Observer(listener: listener, dispatchQueue: dispatchQueue))
    }
    
    static func deregisterListener(token: Token) -> Bool {
        if let token = token as? ListenerToken {
            token.observer.cancel()
            token.observer = nil
            return true
        }
        return false
    }

    // **********************************************************************************************************************
    
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    private(set) var image: UIImage!
    let id: String


    private let imageUrl: URL
    private let location: CLLocation
    private weak var observer: Database.Observer?
    private var _distanceToUser: Double? // Units are yards
    private var management: ListenerManagement? = nil

    
    private init?(properties: Dictionary<String, Any>, observer: Database.Observer) {
        if  let id = properties["uid"], let name = properties["name"], let latitude = properties["latitude"],
            let longitude = properties["longitude"], let description = properties["description"], let imageUrl = properties["imageUrl"] {
            
            self.id = id as! String
            self.name = name as! String
            self.description = description as! String

            coordinate = CLLocationCoordinate2D(latitude: latitude as! Double, longitude: longitude as! Double)
            location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
           
            let url = URL(string: imageUrl as! String)
            if url == nil { return nil }
            self.imageUrl = url!

            if let userLocation = UserLocation.instance?.current {
                _distanceToUser = distanceToUser(userLocation: userLocation)
            }

            self.observer = observer // Inform the observer of location updates
            management = UserLocation.instance?.addListener(self, handlerClassMethod: PointOfInterest.userLocationEventHandler) // Listen to location updates
        }
        else {
            return nil
        }
    }
    
    var distanceToUser: String {
        if let distance = _distanceToUser {
            return "\(Int(round(distance))) yds"
        }
        return "<unknown>"
    }

    private func distanceToUser(userLocation: CLLocation) -> Double {
        let YardsPerMeter = 1.0936
        return userLocation.distance(from: self.location) * YardsPerMeter
    }

    // When updates are received from the database the observers will be sent a new version of a Point of Interest.
    // If the observer releases the previous version that it had received then the UserLocation will stop sendimg
    // location events to that previous instance. This is due to the fact that Broadcasters (which the UserLocation
    // is) store their listener references weakly.
    private func userLocationEventHandler(event: UserLocationEvent) {
        if case .locationUpdate(let userLocation) = event {
            _distanceToUser = distanceToUser(userLocation: userLocation)
        
            if let observer = self.observer {
                observer.notify(poi: self, event: .updated)
            }
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
            
            private var listener: Listener
            private var dispatchQueue: DispatchQueue
            private var reference: FIRDatabaseReference
            
            fileprivate init(listener: @escaping Listener, dispatchQueue: DispatchQueue) {
                self.listener = listener
                self.dispatchQueue = dispatchQueue
                self.reference = FIRDatabase.database().reference(withPath: Observer.path)
                
                reference.observe(.childAdded,   with: { self.create(properties: $0.value as! [String: Any], event: .added) })
                reference.observe(.childChanged, with: { self.create(properties: $0.value as! [String: Any], event: .updated) })
                reference.observe(.childRemoved, with: { self.create(properties: $0.value as! [String: Any], event: .removed) })
            }
            
            deinit {
                cancel()
            }
            
            fileprivate func cancel() {
                reference.removeAllObservers()
            }
            
            private func create(properties: [String: Any], event: Event) {
                if let poi = PointOfInterest(properties: properties, observer: self) {
                    loadImage(poi: poi) {
                        self.dispatchQueue.async {
                            self.listener(poi, event)
                        }
                    }
                }
                else {
                    print("Invalid POI data: \(properties)")
                }
            }
            
            fileprivate func notify(poi: PointOfInterest, event: Event) {
                dispatchQueue.async { self.listener(poi, event) }
            }
            
            private func loadImage(poi: PointOfInterest, complete: @escaping () -> Void) {
                let session = URLSession(configuration: .default)
                let imageDownloadTask = session.dataTask(with: poi.imageUrl) { (data, response, error) in
                    
                    var image: UIImage?
                    var errorText = ""
                    
                    if let error = error {
                        errorText = "Error = \(error)"
                    }
                    else {
                        if let response = response as? HTTPURLResponse {
                            if response.statusCode == 200 {
                                if let data = data {
                                    image = UIImage(data: data)
                                    if image != nil {
                                        UserDefaults.standard.set(data, forKey: poi.id)
                                    }
                                    else {
                                        errorText = "image data is corrupt"
                                    }
                                }
                                else {
                                    errorText = "image data is nil"
                                }
                            }
                            else {
                                errorText = "http response code = \(response.statusCode)"
                            }
                        }
                        else {
                            errorText = "http response is nil"
                        }
                    }
                    
                    if image == nil {
                        // If the image could not be obtained then lets see if we "stashed" it on a previous connection to the database
                        if let imageData = UserDefaults.standard.data(forKey: poi.id) {
                            image = UIImage(data: imageData)
                        }
                            // Else let's create a "standin" image that will inform the user.
                        else { // TODO: Change this to a circle with a line through it.
                            image = self.generateImage(from: "Image Error: \(errorText)")
                        }
                    }
                    
                    poi.image = image!
                    
                    complete()
                }
                imageDownloadTask.resume()
            }
            
            private func generateImage(from: String) -> UIImage {
                let label = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 25))
                label.backgroundColor = UIColor.clear
                label.textAlignment = .center
                label.textColor = UIColor.red
                label.font = UIFont.systemFont(ofSize: 4)
                label.numberOfLines = 0
                label.text = from
                
                UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 0);
                label.layer.render(in: UIGraphicsGetCurrentContext()!)
                let textImage = UIGraphicsGetImageFromCurrentImageContext()!
                UIGraphicsEndImageContext();
                
                return textImage
            }
        }
    }

    private class ListenerToken {
        var observer: Database.Observer!
        init(observer: Database.Observer) { self.observer = observer }
    }
    
}
