//
//  ViewController.swift
//  UserPath
//
//  Created by Robert Vaessen on 9/16/17.
//  Copyright © 2017 Robert Vaessen. All rights reserved.
//

import UIKit
import VerticonsToolbox
import CoreLocation
import MapKit

class Marker : NSObject, MKAnnotation {
    
    static private var counter = 1

    var viewObservation: NSKeyValueObservation?
    var viewPosition: CGPoint? {
        didSet {
            let now = Date()
            if let lastPosition = oldValue, let lastTime = viewPositionUpdateTime {
                let delatX = viewPosition!.x - lastPosition.x
                let deltaY = viewPosition!.y - lastPosition.y
                let deltaPosition = sqrt(delatX*delatX + deltaY*deltaY)
                let deltaTime = now.timeIntervalSince(lastTime)
                viewVelocity = Double(deltaPosition) / deltaTime
            }
            viewPositionUpdateTime = now
        }
    }
    var viewPositionUpdateTime: Date?
    var viewVelocity: Double?

    var title: String?
    var subtitle: String?
    var coordinate: CLLocationCoordinate2D
   
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        title = "Marker \(Marker.counter)"
        Marker.counter += 1
        super.init()
    }
}

class ViewController: UIViewController {

    @IBOutlet fileprivate weak var mapView: MKMapView!
    @IBOutlet fileprivate weak var latStepper: UIStepper!
    private var latStepperObservation: NSKeyValueObservation!
    @IBOutlet fileprivate weak var lngStepper: UIStepper!
    private var lngStepperObservation: NSKeyValueObservation!

    fileprivate var selectedMarkerView: MKPinAnnotationView?
    fileprivate var path: MKPolyline?
    fileprivate var markers = [Marker]()
    fileprivate let iCloud = ICloud()

    private var initialZoomCompleted = false
    private var trackUser = false {
        didSet {
            mapView.showsUserLocation = trackUser
            mapView.showsCompass = trackUser
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        mapView.showsUserLocation = trackUser

        _ = UserLocation.instance.addListener(self, handlerClassMethod: ViewController.userLocationEventHandler)

        let doubleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapMapView))
        doubleTapRecognizer.numberOfTapsRequired = 2
        mapView.gestureView.addGestureRecognizer(doubleTapRecognizer)

        let singleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapMapView))
        singleTapRecognizer.numberOfTapsRequired = 1
        mapView.gestureView.addGestureRecognizer(singleTapRecognizer)
        singleTapRecognizer.require(toFail: doubleTapRecognizer)

        latStepperObservation = latStepper.observe(\.value, options: [.old, .new]) { object, change in
            if  let new = change.newValue, let old = change.oldValue,
                let selected = self.selectedMarkerView, let marker = selected.annotation as? Marker {
                    marker.coordinate.latitude += new > old ? self.latStepper.stepValue : -self.latStepper.stepValue
                    self.mapView.removeAnnotation(marker)
                    self.mapView.addAnnotation(marker)
            }
        }
        lngStepperObservation = lngStepper.observe(\.value, options: [.old, .new]) { object, change in
            if  let new = change.newValue, let old = change.oldValue,
                let selected = self.selectedMarkerView, let marker = selected.annotation as? Marker {
                    marker.coordinate.longitude += new > old ? self.lngStepper.stepValue : -self.lngStepper.stepValue
                    self.mapView.removeAnnotation(marker)
                    self.mapView.addAnnotation(marker)
                }
        }
    }

    @objc func didDoubleTapMapView(recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            let tapPoint = recognizer.location(in: mapView)
            let coordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
            mark(coordinate: coordinate)
        }
    }
    
    @objc func didTapMapView(recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
        }
    }
    
    private func userLocationEventHandler(event: UserLocationEvent) {
        guard !mapView.userIsInteracting else { return }
        
        switch event {
            
        case .locationUpdate(let location):
            if !initialZoomCompleted {
                mapView.region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
                initialZoomCompleted = true
            }

            if trackUser { mapView.setCenter(location.coordinate, animated: false) }
            
        case .headingUpdate(let heading):
            if trackUser { mapView.camera.heading = heading.trueHeading }
            
        default:
            break
        }
    }
}

extension ViewController { // Toolbar Items

    @IBAction func clearMarkers(_ sender: UIBarButtonItem) { clearMarkers() }
    private func clearMarkers() {
        if markers.count > 0 {
            mapView.removeAnnotations(markers)
            markers.removeAll()
        }
    }

    @IBAction func erasePlot(_ sender: UIBarButtonItem) { erasePlot() }
    private func erasePlot() {
        if let path = path {
            mapView.remove(path)
            self.path = nil
        }
    }

    @IBAction func importMarkers(_ sender: UIBarButtonItem) {
        iCloud.importFile(ofType: "json", documentPickerPresenter: self ) { status in
            switch status {
            case .success(_, let contents):
                let prompt = PromptUser("Enter the Coordinates Path") {
                    if let path = $0 {
                        switch contents!.toMarkers(path) {
                        case .success(let markers):
                            self.clearMarkers()
                            self.erasePlot()
                            self.markers = markers
                            self.mapView.addAnnotations(self.markers)
                            self.mapView.setCenter(self.markers[self.markers.count/2].coordinate, animated: true)
                        case .error(let errorText):
                            alertUser(title: "Cannot Load Markers", body: errorText)
                        }
                    }
                }
                self.present(prompt, animated: true)
                
            case .error(let description, let error):
                alertUser(title: "Cannot Import From iCloud", body: "\(description): \(String(describing: error))")
                
            case .cancelled:
                break
            }
        }
    }
    
    @IBAction func markUser(_ sender: UIBarButtonItem) {
        mark(coordinate: UserLocation.instance.currentLocation!.coordinate)
    }
    
    func mark(coordinate: CLLocationCoordinate2D) {
        let marker = Marker(coordinate: coordinate)
        markers.append(marker)
        mapView.addAnnotation(marker)
        mapView.selectAnnotation(marker, animated: true)
    }
    
    @IBAction func plot(_ sender: UIBarButtonItem) {
        guard let startingMarker = selectedMarkerView?.annotation as? Marker else {
            alertUser(title: "Cannot Plot Markers", body: "Please select the stating marker")
            return
        }
        markers.sort(startingWith: startingMarker)

        if let path = path { mapView.remove(path) }
        path = MKPolyline(coordinates: markers.map{ return $0.coordinate }, count: markers.count)
        mapView.add(path!)
    }
    
    @IBAction func exportMarkers(_ sender: UIBarButtonItem) {
        guard let startingMarker = selectedMarkerView?.annotation as? Marker else {
            alertUser(title: "Cannot Export Markers", body: "Please select the stating marker")
            return
        }
        markers.sort(startingWith: startingMarker)

        let prompt = PromptUser("Enter the Coordinates Path") {
            if let path = $0 {
                self.iCloud.exportFile(contents: self.markers.toJson(path), name: "Path.json", documentPickerPresenter: self) { status in
                    switch status {
                    case .success(let url):
                        print("Exported to \(url)")
                        
                    case .error(let description, let error):
                        alertUser(title: "Cannot Export to iCloud", body: "\(description): \(String(describing: error))")
                        
                    case .cancelled:
                        print("Cancelled")
                    }
                }
            }
        }
        present(prompt, animated: true)
    }
    
    @IBAction func emailMarkers(_ sender: UIBarButtonItem) {
        let prompt = PromptUser("Enter the Coordinates Path") {
            if let path = $0 {
                _ = Email.sender.send(to: ["you@yourdomain.com"], subject: "TOH Coordinates", message: self.markers.toJson(path), presenter: self)
            }
        }
        present(prompt, animated: true)
    }

    @IBAction func changeMapType(_ sender: UIBarButtonItem) {
        switch mapView.mapType {
        case .standard:
            mapView.mapType = .satellite
            sender.title = "Sat"
        case .satellite:
            mapView.mapType = .hybrid
            sender.title = "Hyb"
        default:
            mapView.mapType = .standard
            sender.title = "Std"
        }
    }

    @IBAction func toggleTracking(_ sender: UIBarButtonItem) {
        trackUser = !trackUser
    }
}

private extension Array where Element == Marker {
    func toJson(_ path: String) -> String {
        var json = "{ \"\(path)\" : {\n"
        
        var entry = 1
        self.forEach { marker in
            json +=  entry > 1 ? ",\n" : "" // Add a comma to the end of the previous entry. The final entry will not have a comma at the end (python's json didn't like it)
            json += String(format: "\"%03d\" : { \"latitude\" : \(marker.coordinate.latitude), \"longitude\" : \(marker.coordinate.longitude) }", entry)
            entry += 1
        }
        
        json += "\n} }"
        
        return json
    }
    
    mutating func sort(startingWith: Marker) {
        var sorted = [Marker]()

        var next = startingWith
        repeat {
            sorted.append(next)
            remove(at: index(of: next)!)

            let prior = next.coordinate
            var seperation = Double.infinity
            self.forEach() {
                let delatLat = $0.coordinate.latitude - prior.latitude
                let delatLng = $0.coordinate.longitude - prior.longitude
                let deltaMag = sqrt(delatLat*delatLat + delatLng*delatLng)
                if deltaMag < seperation {
                    next = $0
                    seperation = deltaMag
                }
            }

        } while count > 0

        self = sorted
    }
}

private extension String {
    enum Status {
        case success([Marker])
        case error(String)
    }
    func toMarkers(_ path: String) -> Status {

        guard let jsonData = self.data(using: .utf8) else {
            return .error("The json string could not be converted to a Data object using utf8:\n\(self)")
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)

            if  let container = jsonObject as? [String : [String: Any]],
                let coordinates = container[path] as? [String : [String : Double]] {
                
                var markers = Array<Marker>(repeating: Marker(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)), count: coordinates.count)
                for (key, value) in coordinates {
                    let position = Int(key)!
                    markers[position - 1] = Marker(coordinate: CLLocationCoordinate2D(latitude: value["latitude"]!, longitude: value["longitude"]!))
                }
                return .success(markers)
            }
            else {
                return .error("The json object does not contain the expected types and/or keys:\n\(jsonObject)")
            }
        }
        catch {
            return .error("Error parsing json data: \(error)\n\(data)")
        }
    }
}

extension ViewController : MKMapViewDelegate {

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        //mapView.userTrackingMode = .follow
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseID = "MarkerView"

        if let userLocation = annotation as? MKUserLocation {
            userLocation.subtitle = userLocation.coordinate.description
        }
        else if let marker = annotation as? Marker {
            marker.subtitle = marker.coordinate.description

            if let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) {
                view.annotation = marker
                return view
            }
            
            let pinView = MKPinAnnotationView(annotation: marker, reuseIdentifier: reuseID)
            pinView.canShowCallout = false
            pinView.isDraggable = true

            //let gesture = UIPanGestureRecognizer(target: self, action: #selector(pinGesture))
            //pinView.addGestureRecognizer(gesture)

            return pinView
        }

        return nil
    }

    @objc func pinGesture(recognizer: UIGestureRecognizer) {
        if recognizer.state == .began, let markerView = recognizer.view as? MKAnnotationView, let marker = markerView.annotation as? Marker {
            print("Pin gesture recognized")
            recognizer.isEnabled = false
            mapView.removeAnnotation(marker)
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = UserTrackingPolyline.Renderer(polyline: overlay as! MKPolyline, mapView: mapView)
        renderer.width = 2
        renderer.strokeColor = .red
        return renderer
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard view !== selectedMarkerView else { return }
        
        if let pin = view as? MKPinAnnotationView, pin.annotation is Marker {
 
            if let selected = selectedMarkerView { selected.pinTintColor = MKPinAnnotationView.redPinColor() }

            selectedMarkerView = pin
            pin.pinTintColor = MKPinAnnotationView.purplePinColor()
            
            latStepper.value = 0
            lngStepper.value = 0
        }
    }
    
    // Touching anywhere on the screen results in a deselect
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        //guard view === selectedMarkerView else { return }

        //selectedMarkerView?.pinTintColor = MKPinAnnotationView.redPinColor()
        //selectedMarkerView = nil
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if let marker = view.annotation as? Marker {
            switch newState {
            case .starting:
                marker.viewObservation = view.observe(\.center, options: [.new]) { object, change in
                    if  let new = change.newValue { marker.viewPosition = new }
                }

            case .ending:
                marker.viewObservation = nil
                if let velocity = marker.viewVelocity, velocity > 1000 {
                    mapView.removeAnnotation(marker)
                    markers.remove(at: markers.index(of: marker)!)
                }

            default: break
            }
        }
    }
}
