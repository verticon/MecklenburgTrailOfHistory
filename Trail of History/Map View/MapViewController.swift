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

    class DebugConsole {
        // Display debugging information while we are actually walking the
        // trail (i.e. the dev machine is not attached). Comment out, or not,
        // the instantiation line in viewDidLoad as desired.
        
        private var strings = [Int : String]()
        private let debugLayer: CATextLayer
        
        init(on: UIView) {
            debugLayer = CATextLayer()
            debugLayer.frame = on.bounds
            //debugLayer.alignmentMode = kCAAlignmentCenter
            debugLayer.foregroundColor = UIColor.lightGray.withAlphaComponent(0.6).cgColor
            on.layer.addSublayer(debugLayer)
        }
        
        func update(line: Int, with: String) {
            strings[line] = with

            var orderedStrings = Array<String>(repeating: "", count: strings.count)
            strings.forEach { orderedStrings[$0.key] = $0.value }

            var concatenatedString = ""
            orderedStrings.forEach { concatenatedString += $0 + "\n" }

            debugLayer.string = concatenatedString
        }
    }

    class PathRenderer : ZoomingPolylineRenderer {
        
        // I couldn't figure out how to do it with initialixzers :-(
        func subscribe(to: Path) {
            setColor(path: to)
            _ = to.addListener(self, handlerClassMethod: PathRenderer.pathEventHandler)
        }
        
        private func pathEventHandler(event: PathEvent) {
            if case .userOnChange(let path) = event {
                setColor(path: path)
                setNeedsDisplay()
            }
        }
        
        private let userOnColor = UIColor(red: 33/255, green: 88/255, blue: 17/255, alpha: 1)
        private let userOffColor = UIColor(red: 244/255, green: 43/255, blue: 16/255, alpha: 1)
        private func setColor(path: Path) {
            strokeColor = path.userIsOn ? userOnColor : userOffColor
        }
    }

    // *****************************************************************************

    var pageViewController: PageViewController?

    @IBOutlet fileprivate weak var mapView: MKMapView!

    fileprivate var poiAnnotations = [PoiAnnotation]()

    @IBOutlet fileprivate weak var collectionView : UICollectionView!
    fileprivate let poiCardReuseIdentifier = "PointOfInterestCard"

    private var poiObserverToken: Any!

    fileprivate var trail: Path!
    fileprivate let trailWidth = 3.0 // Meters

    fileprivate var debugConsole: DebugConsole?

    // *****************************************************************************

    override func viewDidLoad() {
        super.viewDidLoad()

        debugConsole = DebugConsole(on: view)

        navigationItem.titleView = UIView.fromNib("Title")
        navigationItem.titleView?.backgroundColor = UIColor.clear // It was set to an opaque color in the NIB so that the white, text images would be visible in the Interface Builder.
        navigationItem.rightBarButtonItem?.tintColor = UIColor.tohTerracotaColor
        navigationItem.leftBarButtonItem?.tintColor = UIColor.tohTerracotaColor

        let poiCardNib = UINib(nibName: "PointOfInterestCard", bundle: nil)
        collectionView.register(poiCardNib, forCellWithReuseIdentifier: poiCardReuseIdentifier)
        collectionView.decelerationRate = UIScrollViewDecelerationRateFast
        
        mapView.showsCompass = true
        mapView.showsUserLocation = true

        switch Path.load(pathName: jsonDataSelector) {
        case .success(let path):
            trail = path
            mapView.add(path.polyline)
            //mapView.add(path.boundingPolygon)
            mapView.region = 1.25 * path.boundingRegion
            mapView.setCenter(path.midCoordinate, animated: true)

        case .error(let message):
            fatalError(message)
        }

        _ = UserLocation.instance.addListener(self, handlerClassMethod: MapViewController.userLocationEventHandler)

        poiObserverToken = PointOfInterest.addObserver(poiObserver, dispatchQueue: DispatchQueue.main)

        OptionsViewController.initialize(delegate: self)
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

    func poiObserver(poi: PointOfInterest, event: PointOfInterest.Event) {

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
            else {
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

                if poiAnnotations.count > 1, let index = poiAnnotations.index(of: new) {
                    collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: true)
                }

                setImagesFor(annotation: new, isCurrent: true)
            }
        }
    }

    private var lastInteractionTime = Date()
    private func userLocationEventHandler(event: UserLocationEvent) {
        guard !mapView.userIsInteracting else { lastInteractionTime = Date(); return }
        guard DateInterval(start: lastInteractionTime, end: Date()).duration > 3 else { return }
        
        switch event {
        case .locationUpdate(let location):
            self.mapView.setCenter(location.coordinate, animated: false)
        case .headingUpdate(let heading):
            self.mapView.camera.heading = heading.trueHeading
        default:
            break
        }
        
        func poiIsInFrontOfUser(_ poi: PointOfInterest) -> Bool {
            guard let angle = poi.angleWithUserHeading else {
                print("Warning: could not obtain the user -> poi angle???")
                return true // Include everthing
            }
            
            let capture = 90.0
            return angle <= capture/2.0 || angle > 360.0 - capture/2 // capture/2 degrees to either side of user's current heading
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

extension MapViewController : MKMapViewDelegate {

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        //mapView.userTrackingMode = .follow
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
            userLocation.subtitle = "lat \(String(format: "%.6f", userLocation.coordinate.latitude)), long \(String(format: "%.6f", userLocation.coordinate.longitude))"
        }
        
        return nil
    }
    
    // Make the selected point of interest the new current POI
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let selected = view.annotation as? PoiAnnotation { currentPoi = selected }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer : MKOverlayPathRenderer
        if overlay is MKPolygon {
            renderer = MKPolygonRenderer(polygon: overlay as! MKPolygon)
            renderer.lineWidth = 2
            renderer.strokeColor = .red
        }
        else {
            let pathRenderer = PathRenderer(polyline: overlay as! MKPolyline, mapView: mapView, polylineWidth: trailWidth)
            pathRenderer.subscribe(to: trail)
            renderer = pathRenderer
        }
        renderer.fillColor = .clear
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
         }

        if !collectionView.isDragging && !collectionView.isDecelerating { timer.invalidate() }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        DetailView.present(poi: poiAnnotations[indexPath.item].poi)
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
        mapView.region = trail.boundingRegion
    }

    func zoomToUser() {
        let userRect = makeRect(center: mapView.userLocation.coordinate, span: trail.boundingRegion.span)
        mapView.region = MKCoordinateRegionForMapRect(userRect)
    }

    func zoomToBoth() {
        mapView.region = trail.boundingRegion
        if !mapView.isUserLocationVisible {
            let trailRect = makeRect(center: trail.boundingRegion.center, span: trail.boundingRegion.span)
            let userRect = makeRect(center: mapView.userLocation.coordinate, span: trail.boundingRegion.span)
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

