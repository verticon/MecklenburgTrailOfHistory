//
//  MapViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 8/22/16.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import UIKit
import MapKit
import VerticonsToolbox

/* The Map View Controller presents a MKMapView and a UICollectionView. Each of these two views present the Trail of History's
 * points of interest. The map view presents a set of annotations. The collection view presents a set of cards. The map view
 * controller uses the concept of a "current" point of interest to keep these two views in sync. The current point of interest
 * is the one whose card is centered in the card collection view and whose map annotation is highlighted and centered in the map.
 * Initially the current point of interest is set to the middle (from an east/west perspective) point of interest.
 *
 * The user can change the current point of interest in one of two ways:
 *      1) By tapping on a different map annotation. The controller will highlight that annotation and center the map on it.
 *      2) By scrolling the collection view to a different card.
 * Whenever the user performs one of the above actions, the controller will automatically perform the other. Thus the annotations
 * and the cards are always kept in sync, each indicating the same current point of interest.
 *
 * The Map View Controller also gives the user access to an Options View Controller (via a small drop down arrow to the right
 * of the title view). The Options controller allows the user to set various features and to perform various actions.
 */

class MapViewController: UIViewController {

    class PoiAnnotation: NSObject, MKAnnotation {
 
        var title: String?
        var subtitle: String?
        var coordinate: CLLocationCoordinate2D

        var poi: PointOfInterest

        init(poi: PointOfInterest) {
            title = poi.name
            coordinate = poi.location.coordinate
            subtitle = "lat \(coordinate.latitude), long \(coordinate.longitude)"

            self.poi = poi
        }

        func update(with poi: PointOfInterest) {
            title = poi.name
            coordinate = poi.location.coordinate
            subtitle = "lat \(coordinate.latitude), long \(coordinate.longitude)"
            
            self.poi = poi
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let lhs = object as? PoiAnnotation else { return false }
            return lhs.poi == poi
        }
    }

    // *****************************************************************************

    var pageViewController: PageViewController?

    private var busyIndicator: UIActivityIndicatorView!
    private var busyImage: UIImageView!

    @IBOutlet weak var pageSwiper: PageSwiper!

    @IBOutlet weak var mapView: MKMapView!

    private var listenerToken: PointOfInterest.ListenerToken!
    var poiAnnotations = [PoiAnnotation]()

    @IBOutlet weak var collectionView : UICollectionView!
    fileprivate let poiCardReuseIdentifier = "PointOfInterestCard"

    var trailLoaded = false
    var userTrackingPolyline: UserTrackingPolyline?
    let polylineWidth = 4.0 // meters

    private var userTrackingButton: UserTrackingButton!

    private var userIsOnAnnotation = MKPointAnnotation()
    private var userIsOnAnnotationAnimator: UIViewPropertyAnimator?
    
    private var debugConsole: DebugLayer?

    // *****************************************************************************

    override func viewDidLoad() {
        super.viewDidLoad()

        startBusy()

        view.sendSubview(toBack: pageSwiper)
        pageSwiper.backgroundColor = UIColor.tohGreyishBrownTwoColor
        pageSwiper.direction = .right

        do {
            userTrackingButton = UserTrackingButton(mapView: mapView, stateChangeHandler: setUserTracking(_:))
            userTrackingButton.translatesAutoresizingMaskIntoConstraints = false
            mapView.addSubview(userTrackingButton)
            NSLayoutConstraint.activate([
                userTrackingButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 32),
                userTrackingButton.leftAnchor.constraint(equalTo: mapView.leftAnchor, constant: 32),
                userTrackingButton.heightAnchor.constraint(equalToConstant: 32),
                userTrackingButton.widthAnchor.constraint(equalToConstant: 32)
            ])
            
            trackingUser = userTrackingButton.trackingUser
            mapView.showsCompass = false
        }
        
        do {
            navigationItem.rightBarButtonItem?.tintColor = UIColor.tohTerracotaColor
            navigationItem.leftBarButtonItem?.tintColor = UIColor.tohTerracotaColor
        }

        do {
            let poiCardNib = UINib(nibName: "PointOfInterestCard", bundle: nil)
            collectionView.register(poiCardNib, forCellWithReuseIdentifier: poiCardReuseIdentifier)
            collectionView.decelerationRate = UIScrollViewDecelerationRateFast
        }
    
        _ = UserLocation.instance.addListener(self, handlerClassMethod: MapViewController.userLocationEventHandler)

        //debugConsole = DebugLayer.add(to: view)
    }

    private(set) var isBusy: Bool = true
    private func startBusy() {
        print("Map View: starting busy")

        busyImage = UIImageView(image: #imageLiteral(resourceName: "CaptainJack"))
        busyImage.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(busyImage)
        NSLayoutConstraint.activate([
            busyImage.topAnchor.constraint(equalTo: view.topAnchor),
            busyImage.leftAnchor.constraint(equalTo: view.leftAnchor),
            busyImage.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            busyImage.rightAnchor.constraint(equalTo: view.rightAnchor)
            ])
        
        busyIndicator = UIActivityIndicatorView()
        busyIndicator.activityIndicatorViewStyle = .whiteLarge
        busyIndicator.color = UIColor.tohTerracotaColor
        busyIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(busyIndicator)
        NSLayoutConstraint.activate([
            busyIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            busyIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        busyIndicator.hidesWhenStopped = true

        busyIndicator.startAnimating()
    }

    private func stopBusy() {
        print("Map View: stopping busy")

        busyIndicator.stopAnimating()
        let animation = { self.busyImage.bounds.size = CGSize(width: 0, height: 0) }
        UIView.animate(withDuration: 1, animations: animation) { _ in self.busyImage.removeFromSuperview() }
        isBusy = false
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationItem.hidesBackButton = true

        if let pageVC = pageViewController {
            pageVC.navigationItem.leftBarButtonItems = self.navigationItem.leftBarButtonItems
            pageVC.navigationItem.rightBarButtonItems = self.navigationItem.rightBarButtonItems
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "Unwind Map", let pageVC = pageViewController  {
            pageVC.switchPages(sender: self)
            return false
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {

        case "Show Options"?:
            let optionsViewController = segue.destination as! OptionsViewController
            // TODO: Calculate the preferred size from the actual content of the Options controller's table.
            optionsViewController.preferredContentSize = CGSize(width: 150, height: 325)
            optionsViewController.delegate = self

            let presentationController = optionsViewController.popoverPresentationController!
            presentationController.barButtonItem = sender as? UIBarButtonItem
            presentationController.delegate = optionsViewController

        default:
            break
        }
    }

    func poiListener(event: Firebase.Observer.Event, key: Firebase.Observer.Key, poi: PointOfInterest) {

        switch event {

        case .added:
            print("Map View: added \(poi.name)")
    
            let annotation = PoiAnnotation(poi: poi)
            poiAnnotations.append(annotation)

            poiAnnotations = poiAnnotations.sorted { $0.poi.location.coordinate.latitude > $1.poi.location.coordinate.latitude } // Northmost first

            mapView.addAnnotation(annotation)

            // The Captain Jack busy image collapses to the center when it is removed.
            // Make Captain Jack the initial, current POI so that it is the point whereto the busy image collapses.
            if annotation.poi.name == "Captain Jack" {
                currentPoi = annotation
                mapView.setCenter(currentPoi!.coordinate, animated: false)
            }

        case .updated:
            if let index = poiAnnotations.index(where: { $0.poi.name == poi.name }) {
                poiAnnotations[index].update(with: poi)
            }
            else { // TODO: Look into the log files
                print("An unrecognized POI was updated: \(poi.name)")
            }

        case .removed:
            if let index = poiAnnotations.index(where: { $0.poi.name == poi.name }) {
                let removed = poiAnnotations.remove(at: index)
                mapView.removeAnnotation(removed)
                if poiAnnotations.count == 0 { currentPoi = nil }
            }
            else {
                print("An unrecognized POI was removed: \(poi.name)")
            }
        }

        collectionView.reloadData()
        if currentPoi != nil { _ = scroll(collection: collectionView, to: currentPoi!) }// TODO: Add a comment about why we do this each time. Something doesn't work properly if we choose only one, say the first one.
    }

    private var _currentPoi: PoiAnnotation?
    fileprivate var currentPoi: PoiAnnotation? {
        get {
            return _currentPoi
        }
        set {

            func setImages(for: PoiAnnotation, isCurrent: Bool) {
                mapView.view(for: `for`)?.image = isCurrent ? #imageLiteral(resourceName: "CurrentPoiAnnotationImage") : #imageLiteral(resourceName: "PoiAnnotationImage")
                if let index = poiAnnotations.index(where: { $0.poi.name == `for`.poi.name }) {
                    (collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? PointOfInterestCard)?.imageView.image = isCurrent ? #imageLiteral(resourceName: "CurrentPoiAnnotationImage") : #imageLiteral(resourceName: "PoiAnnotationImage")
                }
            }
            
            guard newValue != _currentPoi else { return }

            if let old = _currentPoi {
                setImages(for: old, isCurrent: false)
            }

            _currentPoi = newValue

            if let new = _currentPoi {
                //let didZoom = mapView.region.zoomOut(to: new.coordinate)

                //if poiAnnotations.count > 1, let index = poiAnnotations.index(of: new) {
                //    collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: true)
                //}

                setImages(for: new, isCurrent: true)
            }
        }
    }

    private var lastInteractionTime = Date() // TODO: Account for card view interaction as well
    private func userLocationEventHandler(event: UserLocationEvent) {

        // If the user has been changing the map then leave it alone for a bit
        let interactionTimeout = 3.0 // Seconds
        guard !mapView.userIsInteracting else { lastInteractionTime = Date(); return }
        guard DateInterval(start: lastInteractionTime, end: Date()).duration > interactionTimeout else { return }


        switch event {
        case .locationUpdate(let location):
            collectionView.reloadData()
            mapView.userLocation.subtitle = location.coordinate.description
            if location.horizontalAccuracy < 20 { userTrackingPolyline?.enableTracking(withTolerence: 2*polylineWidth) }
            if trackingUser { self.mapView.setCenter(location.coordinate, animated: false) }
            
        case .headingUpdate(let heading):
            if trackingUser {
                self.mapView.camera.heading = heading.trueHeading

                //if let isOn = userTrackingPolyline?.userIsOn, isOn {
                    
                    func isInFront(_ poi: PointOfInterest) -> Bool {
                        guard let angle = poi.angleWithUserHeading else {
                            print("Warning: could not obtain the user -> poi angle???")
                            return true // Include everthing
                        }
                        
                        let cone = 90.0
                        return angle <= cone/2.0 || angle > 360.0 - cone/2 // cone/2 degrees to either side of user's current heading
                    }
                    
                    func compareDistances(_ poi1: PointOfInterest, _ poi2: PointOfInterest) -> Bool {
                        guard let distance1 = poi1.distanceToUser, let distance2 = poi2.distanceToUser else {
                            print("Warning: could not obtain the user -> poi distances???")
                            return false // Don't sort
                        }
                        
                        return distance1 < distance2
                    }
                    
                    func compareAngles(_ poi1: PointOfInterest, _ poi2: PointOfInterest) -> Bool {
                        guard var angle1 = poi1.angleWithUserHeading, var angle2 = poi2.angleWithUserHeading else {
                            print("Warning: could not obtain the user -> poi angles???")
                            return false // Don't sort
                        }
                        
                        // -180 -> 180 instead of 0 -> 360
                        if angle1 > 180 { angle1 = angle1 - 360 }
                        if angle2 > 180 { angle2 = angle2 - 360 }

                        return abs(angle1) < abs(angle2)
                    }
                    
                    currentPoi = poiAnnotations.sorted{ compareAngles($0.poi, $1.poi) }.first
                    if let poi = currentPoi { _ = scroll(collection: collectionView, to: poi) }
                //}
            }
        default:
            break
        }


        if let console = debugConsole, let tracker = userTrackingPolyline {
            var state = "???"
            if let isOn = tracker.userIsOn { state = isOn  ? "On" : "Off" }
            var distance = "???"
            if let dist = tracker.userTrackingData?.distance { distance = String(format: "%.1f", dist) }
            console.update(line: 1, with: "\(state), dist = \(distance)")
        }


    }

    private func setUserTracking(_ state: Bool) {
        trackingUser = state
    }
    
    private var trackingUser: Bool = false {
        didSet {
            if trackingUser {
                if let location = mapView.userLocation.location { mapView.setCenter(location.coordinate, animated: false) }
                if let heading = mapView.userLocation.heading { mapView.camera.heading = heading.trueHeading }
            }
        }
    }
    
    private func trackngPolylineEventHandler(event: UserTrackingPolylineEvent) {
        
        guard let userLocation = UserLocation.instance.currentLocation, let userIsOn = userTrackingPolyline?.userIsOn, let trackingData = userTrackingPolyline?.userTrackingData else {
            fatalError("User Location and/or Polyline Tracking data is nil. Huh?! How did the event handler even get called?")
        }
        
        switch event {
            
        case .userIsOnChanged:
            print("Map View: User is \(userIsOn ? "on" : "off") trail.")
            userIsOnAnnotationAnimator = UIViewPropertyAnimator(duration: 2, curve: .linear, animations: nil)
            if userIsOn {
                userIsOnAnnotation.coordinate = userLocation.coordinate
                mapView.addAnnotation(userIsOnAnnotation) // The MKMapViewDelegate's didAdd method will animate it into positon (we have to wait for the view to be created and displayed).
                mapView.showsUserLocation = false
            }
            else {
                userIsOnAnnotationAnimator!.addAnimations { // Animate the move from the closest point on the polyline to the user's actual location
                    self.userIsOnAnnotation.coordinate = userLocation .coordinate
                }
                userIsOnAnnotationAnimator!.addCompletion() { animatingPosition in
                    self.mapView.removeAnnotation(self.userIsOnAnnotation)
                    self.mapView.showsUserLocation = true
                    self.userIsOnAnnotationAnimator = nil
                }
                userIsOnAnnotationAnimator!.startAnimation()
            }
            
            
        case .userPositionChanged:
            guard userIsOnAnnotationAnimator == nil else { return }
            userIsOnAnnotation.coordinate = MKCoordinateForMapPoint(trackingData.point)
            userIsOnAnnotation.subtitle = userIsOnAnnotation.coordinate.description
            
        case .trackingDisabled:
            break
        }
    }

    fileprivate func showDetailForCell(at: IndexPath) {
        let cell = collectionView.cellForItem(at: at)!
        let frame = collectionView.convert(cell.frame, to: self.view)
        DetailView.present(poi: poiAnnotations[at.item].poi, startingFrom: frame)
    }
}

extension MapViewController : MKMapViewDelegate {

    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        let mapType = OptionsViewController.getMapType()
        if mapView.mapType != mapType {
            mapView.mapType = mapType // Results in a render
        }
        else if !trailLoaded {
            trailLoaded = true

            loadTrail() {
                switch $0 {
                case .success(let coordinates):
                    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    polyline.title = tohFileName
                    let trackingPolyline = UserTrackingPolyline(polyline: polyline, mapView: mapView)
                    trackingPolyline.renderer.userIsOnColor = UIColor.tohTerracotaColor
                    trackingPolyline.renderer.userIsOffColor = UIColor.tohAdobeColor
                    self.userTrackingPolyline = trackingPolyline
                    self.userIsOnAnnotation.title = mapView.userLocation.title
                    mapView.add(trackingPolyline.polyline)
                    _ = trackingPolyline.addListener(self, handlerClassMethod: MapViewController.trackngPolylineEventHandler)
                    
                case .error(let error):
                    let message = "The map data needed to plot the trail of history could not be obtained. Reason: \(error)"
                    alertUser(title: "Cannot Plot The Trail", body: message)
                    print(message)
                }
                
                self.zoomToTrail() // Results in a render
                self.listenerToken = PointOfInterest.addListener(self.poiListener)
            }
        }
        else {
            self.stopBusy()
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if let annotation = annotation as? PoiAnnotation {
            
            let reuseId = "PoiAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
            if annotationView == nil  { annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId) }
            annotationView!.image = annotation == currentPoi  ? #imageLiteral(resourceName: "CurrentPoiAnnotationImage") : #imageLiteral(resourceName: "PoiAnnotationImage")
            annotationView!.centerOffset = CGPoint(x: 0, y: -annotationView!.bounds.height / 2);
            return annotationView
        }
        
        if annotation === userIsOnAnnotation {
            let reuseID = "UserView"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
                annotationView!.image = UIImage(named: "UserLocation")
                annotationView!.bounds.size = CGSize(width: 32, height: 32)
                annotationView!.centerOffset = CGPoint(x: 0, y: -annotationView!.bounds.height / 2);
                annotationView!.canShowCallout = true
            }
            return annotationView
        }

        if let userLocation = annotation as? MKUserLocation {
            userLocation.subtitle = userLocation.coordinate.description
        }
        
        return nil
    }

    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        views.forEach() { view in
            guard   let annotation = view.annotation as? MKPointAnnotation,
                    annotation === userIsOnAnnotation,
                    userIsOnAnnotationAnimator != nil,
                    let data = userTrackingPolyline?.userTrackingData
            else { return }
            
            // Animate the user location annotation's position from its
            // current, actual user postion to the closest point on the polyline.
            
            let finalCoordinate = MKCoordinateForMapPoint(data.point)
            userIsOnAnnotationAnimator!.addAnimations { annotation.coordinate = finalCoordinate }
            userIsOnAnnotationAnimator!.addCompletion() { position in
                self.userIsOnAnnotationAnimator = nil
                annotation.subtitle = finalCoordinate.description
            }
            userIsOnAnnotationAnimator!.startAnimation()
        }
    }
    

    // For the selected POI: 1) Make it the current POI, 2) scroll the card collection
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let selected = view.annotation as? PoiAnnotation {
            userTrackingButton.trackingUser = false
           currentPoi = selected
            mapView.setCenter(currentPoi!.coordinate, animated: true)
            _ = scroll(collection: collectionView, to: currentPoi!)
       }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

        switch overlay {

        case is MKPolygon:
            let renderer = MKPolygonRenderer(polygon: overlay as! MKPolygon)
            renderer.lineWidth = 2
            renderer.strokeColor = .red
            return renderer
            
        case is MKPolyline:
            if let tracker = userTrackingPolyline {
                tracker.renderer.width = polylineWidth
                return tracker.renderer
            }
            fatalError("Have polyline overlay but no user tracker??")
            
        default:
            fatalError("Unsupported orvelay: \(overlay)")
        }
    }
}

extension MapViewController : UICollectionViewDelegate {
    
    // As the user scrolls a new point of interest card into view, we respond by making that card's POI
    // the current POI. We track the scrolling via a timer which will run for the duration of the scrolling.

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        let timer = Timer(timeInterval: 0.25, target: self, selector: #selector(currentPoiDetectionTimer), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
    }
    
    @objc func currentPoiDetectionTimer(_ timer: Timer) {
        let centerPoint = CGPoint(x: collectionView.frame.width/2, y: collectionView.frame.height/2)
        if let indexOfCenterCell = self.collectionView.indexPathForItem(at: CGPoint(x: centerPoint.x + self.collectionView.contentOffset.x, y: centerPoint.y + self.collectionView.contentOffset.y)) {
            userTrackingButton.trackingUser = false
            currentPoi = poiAnnotations[indexOfCenterCell.item]
            // TODO: Conside panning the map in correspondence to the scrolling of the collection.
            mapView.setCenter(currentPoi!.coordinate, animated: true)
         }

        if !collectionView.isDragging && !collectionView.isDecelerating { timer.invalidate() }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let current = currentPoi, let currentPoiIndex = poiAnnotations.index(where: { $0.poi.name == current.poi.name }), indexPath.item == currentPoiIndex {
            showDetailForCell(at: indexPath)
        }
    }
}

extension MapViewController : UICollectionViewDelegateFlowLayout {
    // The FlowLayout looks for the UICollectionViewDelegateFlowLayout protocol's adoption on whatever object is set as the collection's delegate (i.e. UICollectionViewDelegate)

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let screenSize: CGRect = UIScreen.main.bounds
        return CGSize(width: CGFloat(screenSize.width * 0.8), height: CGFloat(70))
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let screenSize: CGRect = UIScreen.main.bounds
        return CGSize(width: screenSize.width * 0.1, height: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let screenSize: CGRect = UIScreen.main.bounds
        return CGSize(width: screenSize.width * 0.1, height: 0)
    }

//    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
//        return CGSize(width: CGFloat(collectionView.bounds.size.width * 0.8), height: CGFloat(collectionView.bounds.size.height * 0.875))
//    }
//    
//    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
//        return CGSize(width: collectionView.bounds.size.width * 0.1, height: 0)
//    }
//    
//    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
//        return CGSize(width: collectionView.bounds.size.width * 0.1, height: 0)
//    }
}

extension MapViewController : UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return poiAnnotations.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // The points of interest are sorted by longitude, westmost first. The cell at index 0 will use the data from the westmost (first) poi;
        // the cell at index count - 1 will use the data from the eastmost (last) poi. Thus the horizontal sequencing of the cells from left to
        // right mirrors the logitudinal sequencing of the points of interest from west to east.

        let annotation = poiAnnotations[indexPath.item]
        let poi = annotation.poi

        let poiCell = collectionView.dequeueReusableCell(withReuseIdentifier: poiCardReuseIdentifier, for: indexPath) as! PointOfInterestCard
        poiCell.nameLabel.text = poi.name
        poiCell.imageView.image = annotation == currentPoi ? #imageLiteral(resourceName: "CurrentPoiAnnotationImage") : #imageLiteral(resourceName: "PoiAnnotationImage")
        poiCell.distanceLabel.text = poi.distanceToUserText
        poiCell.layer.shadowOpacity = 0.3
        poiCell.layer.masksToBounds = false
        poiCell.layer.shadowOffset = CGSize(width: 4, height: 4)

        poiCell.poi = poi
        
        return poiCell
    }
}

extension MapViewController : OptionsViewControllerDelegate {

    var mapType: MKMapType {
        get {
            return mapView.mapType
        }
        set {
            mapView.mapType = newValue
        }
    }

    func zoomToTrail() {
        userTrackingButton.trackingUser = false

        if let tracker = userTrackingPolyline {
            mapView.region = 1.25 * tracker.polyline.boundingRegion
        }
        else if poiAnnotations.count > 0 {
            let center = poiAnnotations[0].poi.location.coordinate
            let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            let userRect = makeRect(center: center, span: span)
            mapView.region = MKCoordinateRegionForMapRect(userRect)
        }
        else {
            zoomToUser()
        }
    }

    func zoomToUser() {
        userTrackingButton.trackingUser = false
        
        let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        let userRect = makeRect(center: mapView.userLocation.coordinate, span: span)
        mapView.region = MKCoordinateRegionForMapRect(userRect)
    }

    func zoomToBoth() {
        userTrackingButton.trackingUser = false
        
        zoomToTrail()
        if !mapView.isUserLocationVisible {
            let trailRect = makeRect(center: mapView.region.center, span: mapView.region.span)
            let userRect = makeRect(center: mapView.userLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            let combinedRect = MKMapRectUnion(trailRect, userRect)
            mapView.region = MKCoordinateRegionForMapRect(combinedRect)
        }
    }
}

extension MapViewController { // Utility Methods

    func findCentermost() -> PoiAnnotation? { // East to west centermost
        var centermost: PoiAnnotation?
        var delta = Double.greatestFiniteMagnitude
        for annotation in poiAnnotations {
            let newDelta = fabs(mapView.region.center.longitude - annotation.coordinate.longitude)
            if newDelta < delta {
                delta = newDelta
                centermost = annotation
            }
        }
        return centermost
    }
    
    func scroll(collection: UICollectionView, to: PoiAnnotation) -> Bool {
        guard let index = poiAnnotations.index(where: { $0.poi.name == to.poi.name }) else { return false }
        
        let path = IndexPath(row: index, section: 0)
        collectionView.selectItem(at: path, animated: true, scrollPosition: .centeredHorizontally)
        return true
    }
}

