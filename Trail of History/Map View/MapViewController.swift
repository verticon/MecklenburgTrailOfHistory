//
//  MapViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 8/22/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
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
 
        // TODO: Why are these declared dynamic?
        dynamic var title: String?
        dynamic var subtitle: String?
        dynamic var coordinate: CLLocationCoordinate2D

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

    @IBOutlet weak var pageSwiper: PageSwiper!

    @IBOutlet fileprivate weak var mapView: MKMapView!

    private var poiObserverToken: Any!
    fileprivate var poiAnnotations = [PoiAnnotation]()

    @IBOutlet fileprivate weak var collectionView : UICollectionView!
    fileprivate let poiCardReuseIdentifier = "PointOfInterestCard"

    private var pathLoaded = false
    private var userTrackingPolyline: UserTrackingPolyline?
    private let polylineWidth = 4.0 // meters
    
    private var userIsOnAnnotation = MKPointAnnotation()
    private var userIsOnAnnotationAnimator: UIViewPropertyAnimator?
    
    private var debugConsole: DebugLayer?

    // *****************************************************************************

    override func viewDidLoad() {
        super.viewDidLoad()

        view.sendSubview(toBack: pageSwiper)
        pageSwiper.backgroundColor = UIColor.tohTerracotaColor
        pageSwiper.direction = .right

        do {
            let userTrackingButton = UserTrackingButton(mapView: mapView, stateChangeHandler: setUserTracking(_:))
            userTrackingButton.translatesAutoresizingMaskIntoConstraints = false
            mapView.addSubview(userTrackingButton)
            NSLayoutConstraint.activate([
                userTrackingButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 32),
                userTrackingButton.leftAnchor.constraint(equalTo: mapView.leftAnchor, constant: 32),
                userTrackingButton.heightAnchor.constraint(equalToConstant: 32),
                userTrackingButton.widthAnchor.constraint(equalToConstant: 32)])
            
            trackingUser = userTrackingButton.trackingUser
        }
        
        do {
            navigationItem.rightBarButtonItem?.tintColor = UIColor.tohTerracotaColor
            navigationItem.leftBarButtonItem?.tintColor = UIColor.tohTerracotaColor
        }

        do {
            let poiCardNib = UINib(nibName: "PointOfInterestCard", bundle: nil)
            collectionView.register(poiCardNib, forCellWithReuseIdentifier: poiCardReuseIdentifier)
            collectionView.decelerationRate = UIScrollViewDecelerationRateFast

            poiObserverToken = PointOfInterest.addObserver(poiObserver, dispatchQueue: DispatchQueue.main)
        }
    
        _ = UserLocation.instance.addListener(self, handlerClassMethod: MapViewController.userLocationEventHandler)

        OptionsViewController.initialize(delegate: self)

        //debugConsole = DebugLayer.add(to: view)
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

        case "Show Options"?: // TODO: Disable navigating to the List View while the Options View is being displayed.
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

    func poiObserver(event: Firebase.Observer.Event, key: Firebase.Observer.Key, poi: PointOfInterest) {

        switch event {

        case .added:
            let annotation = PoiAnnotation(poi: poi)
            poiAnnotations.append(annotation)
            //poiAnnotations = poiAnnotations.sorted { $0.poi.location.coordinate.longitude < $1.poi.location.coordinate.longitude } // Westmost first
            poiAnnotations = poiAnnotations.sorted { $0.poi.location.coordinate.latitude > $1.poi.location.coordinate.latitude } // Northmost first

            mapView.addAnnotation(annotation)
            currentPoi = annotation // TODO: Add a comment about why we do this each time. Something doesn't work properly if we choose only one, say the first one.

        case .updated:
            if let index = poiAnnotations.index(where: { $0.poi.id == poi.id }) {
                poiAnnotations[index].update(with: poi)
            }
            else { // TODO: Look into the log files
                print("An unrecognized POI was updated: \(poi.name)")
            }

        case .removed:
            if let index = poiAnnotations.index(where: { $0.poi.id == poi.id }) {
                let removed = poiAnnotations.remove(at: index)
                mapView.removeAnnotation(removed)
                if poiAnnotations.count == 0 { currentPoi = nil }
            }
            else {
                print("An unrecognized POI was removed: \(poi.name)")
            }
        }

        collectionView.reloadData()
    }

    private var _currentPoi: PoiAnnotation?
    fileprivate var currentPoi: PoiAnnotation? {
        get {
            return _currentPoi
        }
        set {

            func setImagesFor(annotation: PoiAnnotation, isCurrent: Bool) {
                mapView.view(for: annotation)?.image = isCurrent ? #imageLiteral(resourceName: "CurrentPoiAnnotationImage") : #imageLiteral(resourceName: "PoiAnnotationImage")
                if let index = poiAnnotations.index(where: { $0.poi.id == annotation.poi.id }) {
                    (collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? PointOfInterestCard)?.imageView.image = isCurrent ? #imageLiteral(resourceName: "CurrentPoiAnnotationImage") : #imageLiteral(resourceName: "PoiAnnotationImage")
                }
            }
            
            guard newValue != _currentPoi else { return }

            if let old = _currentPoi {
                setImagesFor(annotation: old, isCurrent: false)
            }

            _currentPoi = newValue

            if let new = _currentPoi {
                //let didZoom = mapView.region.zoomOut(to: new.coordinate)
                //debugConsole?.update(line: 0, with: "\(didZoom ? "Did Zoom" : "Didn't Zoom")")

                //if poiAnnotations.count > 1, let index = poiAnnotations.index(of: new) {
                //    collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: true)
                //}

                setImagesFor(annotation: new, isCurrent: true)
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
            mapView.userLocation.subtitle = location.coordinate.description
            if location.horizontalAccuracy < 20 { userTrackingPolyline?.enableTracking(withTolerence: polylineWidth) }
            if trackingUser { self.mapView.setCenter(location.coordinate, animated: false) }
            
            if let data = userTrackingPolyline?.userTrackingData { debugConsole?.update(line: 6, with: String(format: "Distance = %.1f meters", data.distance)) }
            debugConsole?.update(line: 7, with: String(format: "Accuracy = %.1f meters", location.horizontalAccuracy))
        case .headingUpdate(let heading):
            if trackingUser { self.mapView.camera.heading = heading.trueHeading }
        default:
            break
        }


        if let isOn = userTrackingPolyline?.userIsOn, isOn { // If the user is on the trail then set the current POI to the next one that he/she will encounter.

            func poiIsInFrontOfUser(_ poi: PointOfInterest) -> Bool {
                guard let angle = poi.angleWithUserHeading else {
                    print("Warning: could not obtain the user -> poi angle???")
                    return true // Include everthing
                }
                
                let cone = 90.0
                return angle <= cone/2.0 || angle > 360.0 - cone/2 // cone/2 degrees to either side of user's current heading
             }

            func poiIsCloserToUser(_ poi1: PointOfInterest, _ poi2: PointOfInterest) -> Bool {
                guard let distance1 = poi1.distanceToUser, let distance2 = poi2.distanceToUser else {
                    print("Warning: could not obtain the user -> poi distance???")
                    return false // Don't sort
                }

                return distance1 < distance2
            }

            currentPoi = poiAnnotations.filter{ poiIsInFrontOfUser($0.poi) }.sorted{ poiIsCloserToUser($0.poi, $1.poi) }.first
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
        
        debugConsole?.update(line: 5, with: "\(userIsOn ? "On" : "Off"), tol. = \(String(format: "%.1f", userTrackingPolyline?.trackingTolerence ?? 0))")
        
        switch event {
            
        case .userIsOnChanged:
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

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        if !pathLoaded {
            LoadPath(mapView: mapView) {
                switch $0 {
                case .success(let trackingPolyline):
                    trackingPolyline.renderer.userIsOnColor = UIColor.tohTerracotaColor
                    trackingPolyline.renderer.userIsOffColor = UIColor.tohDullYellowColor
                    self.userTrackingPolyline = trackingPolyline
                    self.userIsOnAnnotation.title = mapView.userLocation.title
                    mapView.add(trackingPolyline.polyline)
                    _ = trackingPolyline.addListener(self, handlerClassMethod: MapViewController.trackngPolylineEventHandler)
                    self.zoomToTrail()

                case .error(let error):
                    alertUser(title: "\(applicationName) Error", body: "The map data needed to plot the trail of history could not be obtained. Reason: \(error)")
                }
            }
            zoomToTrail()
            pathLoaded = true
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if let annotation = annotation as? PoiAnnotation {
            
            let reuseId = "PoiAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
            if annotationView == nil  {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            }
            
            annotationView!.image = annotation == currentPoi  ? #imageLiteral(resourceName: "CurrentPoiAnnotationImage") : #imageLiteral(resourceName: "PoiAnnotationImage")
            return annotationView
        }
        
        if let userLocation = annotation as? MKUserLocation {
            userLocation.subtitle = userLocation.coordinate.description
        }
        
        return nil
    }
    
    // For the selected POI: 1) Make it the current POI, 2) scroll the card collection, 3) show the detail
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let selected = view.annotation as? PoiAnnotation {
            currentPoi = selected
            if let index = poiAnnotations.index(where: { $0.poi.id == selected.poi.id }) {
                let path = IndexPath(row: index, section: 0)
                collectionView.selectItem(at: path, animated: true, scrollPosition: .centeredHorizontally)
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { // Wait for the scrolling to complete.
                    self.showDetailForCell(at: path)
                }
            }
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer : MKOverlayPathRenderer
        if overlay is MKPolygon {
            renderer = MKPolygonRenderer(polygon: overlay as! MKPolygon)
            renderer.lineWidth = 2
            renderer.strokeColor = .red
        }
        else if let tracker = userTrackingPolyline {
            renderer = tracker.renderer
            tracker.renderer.width = polylineWidth
        }
        else {
            fatalError("Unsupported orvelay: \(overlay)")
        }
        return renderer
    }
}

extension MapViewController : UICollectionViewDelegate {
    
    // As the user scrolls a new point of interest card into view, we respond by making that card's POI
    // the current POI. We track the scrolling via a timer which will run for the duration of the scrolling.

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        //NSTimer.scheduledTimerWithTimeInterval(0.25, target: self, selector: #selector(currentPoiDetectionTimer), userInfo: nil, repeats: true)
        let timer = Timer(timeInterval: 0.25, target: self, selector: #selector(currentPoiDetectionTimer), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
    }
    
    @objc func currentPoiDetectionTimer(_ timer: Timer) {
        let centerPoint = CGPoint(x: collectionView.frame.width/2, y: collectionView.frame.height/2)
        if let indexOfCenterCell = self.collectionView.indexPathForItem(at: CGPoint(x: centerPoint.x + self.collectionView.contentOffset.x, y: centerPoint.y + self.collectionView.contentOffset.y)) {
            currentPoi = poiAnnotations[indexOfCenterCell.item]
            mapView.setCenter(currentPoi!.coordinate, animated: true)
         }

        if !collectionView.isDragging && !collectionView.isDecelerating { timer.invalidate() }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let current = currentPoi, let currentPoiIndex = poiAnnotations.index(where: { $0.poi.id == current.poi.id }), indexPath.item == currentPoiIndex {
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
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let userRect = makeRect(center: mapView.userLocation.coordinate, span: span)
        mapView.region = MKCoordinateRegionForMapRect(userRect)
    }

    func zoomToBoth() {
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
}

