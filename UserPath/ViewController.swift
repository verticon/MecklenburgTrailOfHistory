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

class ViewController: UIViewController {

    class Marker : NSObject, MKAnnotation {

        var title: String? {
            return "lat \(coordinate.latitude), lng \(coordinate.longitude)"
        }
        var subtitle: String?
        var coordinate: CLLocationCoordinate2D {
            return CLLocationCoordinate2D(latitude: initialCoordinate.latitude + latitudeAdjustmewnt, longitude: initialCoordinate.longitude + longitudeAdjustmewnt)
        }

        var latitudeAdjustmewnt: CLLocationDegrees = 0
        var longitudeAdjustmewnt: CLLocationDegrees = 0
        
        private let initialCoordinate = (UserLocation.instance.currentLocation?.coordinate)!
    }
    
    @IBOutlet private weak var mapView: MKMapView!
    
    fileprivate var selectedMarker: Marker?

    private var path: MKPolyline?
    private var markers = [Marker]()
    private var initialZoomCompleted = false

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self

        _ = UserLocation.instance.addListener(self, handlerClassMethod: ViewController.userLocationListener)
    }

    private func userLocationListener(event: UserLocationEvent) {

        if case .locationUpdate(let location) = event {

            if !initialZoomCompleted {
                let userRect = makeRect(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
                mapView.region = MKCoordinateRegionForMapRect(userRect)

                initialZoomCompleted = true
            }
        }
    }

    @IBAction func mark(_ sender: UIButton) {
        let marker = Marker()
        markers.append(marker)
        mapView.addAnnotation(marker)
    }
    
    @IBAction func plot(_ sender: UIButton) {
        if let path = path { mapView.remove(path) }
        path = MKPolyline(coordinates: markers.map{ return $0.coordinate }, count: markers.count)
        mapView.add(path!)
    }

    @IBAction func export(_ sender: UIButton) {

        _ = Email.sender.send(to: ["robert@rvaessen.com"], subject: "TOH Coordinates", message: pathToJson(), presenter: self)
    }
    
    @IBAction func clearPins(_ sender: UIButton) {
        
        if markers.count > 0 {
            mapView.removeAnnotations(markers)
            markers.removeAll()
        }
    }
    
    @IBAction func clearPath(_ sender: UIButton) {
        
        if let path = path {
            mapView.remove(path)
            self.path = nil
        }
    }
    
    @IBAction func adjustLatitude(_ sender: UIStepper) {
        if let marker = selectedMarker {
            marker.latitudeAdjustmewnt = sender.value
            mapView.removeAnnotation(marker)
            mapView.addAnnotation(marker)
        }
    }
    
    @IBAction func adjustLongitude(_ sender: UIStepper) {
        if let marker = selectedMarker {
            marker.longitudeAdjustmewnt = sender.value
            mapView.removeAnnotation(marker)
            mapView.addAnnotation(marker)
        }
    }

    private func pathToJson() -> String {
        var json = "{ \"UserPath\" : {\n"
        
        var entry = 1
        markers.forEach { marker in
            json +=  entry > 1 ? ",\n" : "" // Add a comma to the end of the previous entry. The final entry will not have a comma at the end (python's json didn't like it)
            json += String(format: "\"%03d\" : { \"latitude\" : \(marker.coordinate.latitude), \"longitude\" : \(marker.coordinate.longitude) }", entry)
            entry += 1
        }

        json += "\n} }"

        return json
    }
}

extension ViewController : MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if let userLocation = annotation as? MKUserLocation {
            userLocation.subtitle = "lat \(String(format: "%.6f", userLocation.coordinate.latitude)), long \(String(format: "%.6f", userLocation.coordinate.longitude))"
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
        if let marker = view.annotation as? Marker {
            selectedMarker = marker
            if let pin = view as? MKPinAnnotationView {
                pin.pinTintColor = .green
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        //if let marker = view.annotation as? Marker, marker === selectedMarker { selectedMarker = nil }
        if let pin = view as? MKPinAnnotationView {
            pin.pinTintColor = .red
        }
    }
}
