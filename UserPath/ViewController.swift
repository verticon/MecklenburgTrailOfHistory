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
    
    var title: String?
    var subtitle: String?
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: initialCoordinate.latitude + latitudeAdjustment, longitude: initialCoordinate.longitude + longitudeAdjustment)
    }
    
    var latitudeAdjustment: CLLocationDegrees = 0
    var longitudeAdjustment: CLLocationDegrees = 0
    
    private let initialCoordinate: CLLocationCoordinate2D
    
    init(coordinate: CLLocationCoordinate2D, position: Int) {
        initialCoordinate = coordinate
        title = "Marker \(position)"
        super.init()
    }
}

class ViewController: UIViewController {

    static let jsonKey = "UserPath"

    @IBOutlet fileprivate weak var mapView: MKMapView!
    @IBOutlet fileprivate weak var latStepper: UIStepper!
    @IBOutlet fileprivate weak var lngStepper: UIStepper!

    fileprivate var selectedMarkerView: MKPinAnnotationView?
    fileprivate var path: MKPolyline?
    fileprivate var markers = [Marker]()
    fileprivate let iCloud = ICloud()

    private var initialZoomCompleted = false
    private var trackUser = false

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self

        _ = UserLocation.instance.addListener(self, handlerClassMethod: ViewController.userLocationEventHandler)

        let doubleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapMapView))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        doubleTapRecognizer.delaysTouchesBegan = true
        mapView.gestureView.addGestureRecognizer(doubleTapRecognizer)
    }

    @objc func didDoubleTapMapView(recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended { trackUser = !trackUser }
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

    @IBAction func adjustLatitude(_ sender: UIStepper) {
        if let selected = selectedMarkerView, let marker = selected.annotation as? Marker {
            marker.latitudeAdjustment = sender.value
            mapView.removeAnnotation(marker)
            mapView.addAnnotation(marker)
        }
    }
    
    @IBAction func adjustLongitude(_ sender: UIStepper) {
        if let selected = selectedMarkerView, let marker = selected.annotation as? Marker {
            marker.longitudeAdjustment = sender.value
            mapView.removeAnnotation(marker)
            mapView.addAnnotation(marker)
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
            case .success(let url, let contents):
                self.clearMarkers()
                self.erasePlot()
                self.markers = contents!.toMarkers()
                self.mapView.addAnnotations(self.markers)

                print("Imported from \(url)")
                
            case .error(let description, let error):
                alertUser(title: "Cannot Import From iCloud", body: "\(description): \(String(describing: error))")
                
            case .cancelled:
                print("Cancelled")
            }
        }
    }
    
    @IBAction func mark(_ sender: UIBarButtonItem) {
        let marker = Marker(coordinate: UserLocation.instance.currentLocation!.coordinate, position: markers.count + 1)
        markers.append(marker)
        mapView.addAnnotation(marker)
    }
    
    @IBAction func plot(_ sender: UIBarButtonItem) {
        if let path = path { mapView.remove(path) }
        path = MKPolyline(coordinates: markers.map{ return $0.coordinate }, count: markers.count)
        mapView.add(path!)
    }
    
    @IBAction func exportMarkers(_ sender: UIBarButtonItem) {
        iCloud.exportFile(contents: markers.toJson(), name: "Path.json", documentPickerPresenter: self) { status in
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
    
    @IBAction func emailMarkers(_ sender: UIBarButtonItem) {
        _ = Email.sender.send(to: ["you@yourdomain.com"], subject: "TOH Coordinates", message: markers.toJson(), presenter: self)
    }
}

private extension Array where Element == Marker {
    func toJson() -> String {
        var json = "{ \"\(ViewController.jsonKey)\" : {\n"
        
        var entry = 1
        self.forEach { marker in
            json +=  entry > 1 ? ",\n" : "" // Add a comma to the end of the previous entry. The final entry will not have a comma at the end (python's json didn't like it)
            json += String(format: "\"%03d\" : { \"latitude\" : \(marker.coordinate.latitude), \"longitude\" : \(marker.coordinate.longitude) }", entry)
            entry += 1
        }
        
        json += "\n} }"
        
        return json
    }
}

private extension String {
    func toMarkers() -> [Marker] {

        guard let jsonData = self.data(using: .utf8) else {
            print("The json string could not be converted to a Data object using utf8:\n\(self)")
            return [Marker]()
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)

            if  let container = jsonObject as? [String : [String: Any]],
                let coordinates = container[ViewController.jsonKey] as? [String : [String : Double]] {
                
                var markers = Array<Marker>(repeating: Marker(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), position: 0), count: coordinates.count)
                for (key, value) in coordinates {
                    let position = Int(key)!
                    markers[position - 1] = Marker(coordinate: CLLocationCoordinate2D(latitude: value["latitude"]!, longitude: value["longitude"]!), position: position)
                }
                return markers
            }
            else {
                print("The json object does not contain the expected types and/or keys:\n\(jsonObject)")
            }
        }
        catch {
            print("Error parsing json string: \(error)\n\(self)")
        }

        return [Marker]()
    }
}

extension ViewController : MKMapViewDelegate {

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        //mapView.userTrackingMode = .follow
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        func describeCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
            return "lat \(String(format: "%.6f", coordinate.latitude)), lng \(String(format: "%.6f", coordinate.longitude))"
        }

        let reuseID = "MarkerView"

        if let userLocation = annotation as? MKUserLocation {
            userLocation.subtitle = describeCoordinate(userLocation.coordinate)
        }
        else if let marker = annotation as? Marker {
            marker.subtitle = describeCoordinate(marker.coordinate)

            if let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) { return view }
            
            let pinView = MKPinAnnotationView(annotation: marker, reuseIdentifier: reuseID)
            pinView.canShowCallout = true
            return pinView
        }

        return nil
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = ZoomingPolylineRenderer(polyline: overlay as! MKPolyline, mapView: mapView, polylineWidth: 2)

        renderer.strokeColor = .red
        renderer.fillColor = .clear

        return renderer
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard view !== selectedMarkerView else { return }
        
        if let pin = view as? MKPinAnnotationView, view.annotation is Marker {
 
            if let selected = selectedMarkerView { selected.pinTintColor = MKPinAnnotationView.redPinColor() }

            selectedMarkerView = pin
            pin.pinTintColor = MKPinAnnotationView.purplePinColor()
            
            latStepper.value = 0
            lngStepper.value = 0
        }
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        //if let marker = view.annotation as? Marker, marker === selectedMarker { selectedMarker = nil }
    }
}
