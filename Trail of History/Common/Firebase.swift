//
//  Firebase
//  Events
//
//  Created by Robert Vaessen on 11/19/17.
//  Copyright © 2017 Robert Vaessen. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase
import VerticonsToolbox

// The Encoding protocol is used by the Firebase.Observer<Type> class. The type being observered
// might need to perform additional initializations before the listener is notified. For example:
// network fetches that were not feasable to be performed by the initializer might be needed.
// Firebase.Observer<Type> makes the data instance responsible for calling the listener. In this
// way the data type being observed as an oppurtunity to perform those additional initialization
// steps if needed.
protocol Encoding : VerticonsToolbox.Encodable {
    typealias T = Firebase.Observer
    func finish(event: T.Event, key: T.Key, listener: @escaping (T.Event, T.Key, Self) -> ())
}


class Firebase {
    
    static let connection = { () -> Connection in
        FirebaseApp.configure()
        Database.database().isPersistenceEnabled = true
        return Connection()
    }()

    enum ConnectionEvent {
        case failed
        case established
        case lost
    }

    class Connection : Broadcaster<ConnectionEvent> {
        
        private static let magicPath = ".info/connected"
        
        private enum ConnectionState {
            case initialCall
            case neverConnected
            case connected
            case disconnected
        }
        
        private let connectedRef: DatabaseReference
        private var connectionState: ConnectionState = .initialCall
        
        fileprivate override init() {
            // At startup time the connection observer will be called twice. The first time with a value of false.
            // The second time with a value of true(false) according to whether everything [Device is connected to the
            // network, Firebase server is up] is(is not) up and running. Thereafter the observer will be called
            // once whenever the connection state changes.
            
            connectedRef = Database.database().reference(withPath: Connection.magicPath)

            super.init()

            connectedRef.observe(.value, with: { snapshot in
                if let connected = snapshot.value as? Bool  { self.isConnected = connected }

                switch self.connectionState {
                    
                case .initialCall:
                    assert(!self.isConnected, "Our assumption that the observer's initial call will be with a value of false has been violated!")
                    self.connectionState = .neverConnected
                    
                case .neverConnected:
                    if self.isConnected {
                        self.connectionState = .connected
                        self.broadcast(.established)
                   } else {
                        self.connectionState = .disconnected
                        self.broadcast(.failed)
                    }
                    
                case .connected:
                    assert(!self.isConnected, "We are already connected. Why are we being called again with a value of true?")
                    if !self.isConnected {
                        self.connectionState = .disconnected
                        self.broadcast(.lost)
                    }
                    
                case .disconnected:
                    assert(self.isConnected, "We are already disconnected. Why are we being called again with a value of false?")
                    if self.isConnected {
                        self.connectionState = .connected
                        self.broadcast(.established)
                    }
                }
            })
        }
 
        private(set) var isConnected = false

    }

    class Observer {
        
        enum Event {
            case added
            case updated
            case removed
        }
        
        typealias Key = String
        typealias Listener = (Event, Key, [String: Any]) -> Void
        
        private var listener: Listener?
        private var reference: DatabaseReference?
        private var childAddedObservationId: UInt = 0
        private var childChangedObservationId: UInt = 0
        private var childRemovedObservationId: UInt = 0
        
        init(path: String, with: @escaping Listener) {
            _ = connection // Ensure that the setup has occurred
            
            self.listener = with
            
            // Note: I tried using a single Observer of the event type .value but each event sent all of the records???
            
            reference = Database.database().reference(withPath: path)
            childAddedObservationId = reference!.observe(.childAdded,   with: { self.eventHandler(event: .added, key: $0.key, properties: $0.value as! [String : Any]) })
            childChangedObservationId = reference!.observe(.childChanged, with: { self.eventHandler(event: .updated, key: $0.key, properties: $0.value as! [String : Any]) })
            childRemovedObservationId = reference!.observe(.childRemoved, with: { self.eventHandler(event: .removed, key: $0.key, properties: $0.value as! [String : Any]) })
        }
        
        fileprivate init(path: String) {
            _ = connection // Ensure that the setup has occurred
            
            // Note: I tried using a single Observer of the event type .value but each event sent all of the records???
            
            reference = Database.database().reference(withPath: path)
            childAddedObservationId = reference!.observe(.childAdded,   with: { self.eventHandler(event: .added, key: $0.key, properties: $0.value as! [String : Any]) })
            childChangedObservationId = reference!.observe(.childChanged, with: { self.eventHandler(event: .updated, key: $0.key, properties: $0.value as! [String : Any]) })
            childRemovedObservationId = reference!.observe(.childRemoved, with: { self.eventHandler(event: .removed, key: $0.key, properties: $0.value as! [String : Any]) })
        }
        
        deinit {
            cancel()
        }
        
        func cancel() {
            if let ref = reference {
                ref.removeObserver(withHandle: childAddedObservationId)
                ref.removeObserver(withHandle: childChangedObservationId)
                ref.removeObserver(withHandle: childRemovedObservationId)
                reference = nil
            }
        }
        
        fileprivate func eventHandler(event: Event, key: String, properties: [String: Any]) {
            guard let listener = listener else { fatalError("There is not a listener") }
            listener(event, key, properties)
        }
    }
    
    class TypeObserver<Type:Encoding> : Observer {
        
        typealias TypeListener = (Event, Key, Type) -> Void
        
        private var typeListener: TypeListener

        init(path: String, with: @escaping TypeListener) {
            self.typeListener = with
            super.init(path: path)
        }

        fileprivate override func eventHandler(event: Event, key: String, properties: [String: Any]) {
            guard let data = Type(properties) else { fatalError("Cannot initialize \(Type.self) using \(properties)") }
            data.finish(event: event, key: key, listener: typeListener)
        }
    }
}


