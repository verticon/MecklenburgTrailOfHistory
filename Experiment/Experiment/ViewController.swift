//
//  ViewController.swift
//  Maps
//
//  Created by Robert Vaessen on 10/24/17.
//  Copyright © 2017 Robert Vaessen. All rights reserved.
//

import UIKit
import MapKit
import VerticonsToolbox

class ViewController: UIViewController {

    @IBOutlet private weak var toolbar: UIToolbar!
    @IBOutlet private weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()

        _ = UserLocation.instance.addListener(self, handlerClassMethod: ViewController.userLocationEventHandler)

        toolbar.items?.append(MKUserTrackingBarButtonItem(mapView: mapView))
    }

    private func userLocationEventHandler(event: UserLocationEvent) {
    }
}

extension ViewController : MKMapViewDelegate {
    
}
