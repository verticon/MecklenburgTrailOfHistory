//
//  DummyListTableViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 8/24/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
//

import UIKit
import VerticonsToolbox

class ListViewController : UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageSwiper: PageSwiper!

    var pageViewController: PageViewController?

    fileprivate let poiCellReuseIdentifier = "PointOfInterestCell"
    fileprivate var pointsOfInterest = [PointOfInterest]()
    private var observerToken: Any!

    override func viewDidLoad() {
        super.viewDidLoad()

        pageSwiper.backgroundColor = UIColor.tohGreyishBrownTwoColor
        pageSwiper.direction = .left

        // Hide the left button. It is only there to keep the title in the same position as on the Map View (which has left and right buttons).
        navigationItem.leftBarButtonItem?.tintColor = UIColor.tohGreyishBrownTwoColor // navigationController?.navigationBar.barTintColor
        navigationItem.leftBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.tintColor = UIColor.tohTerracotaColor

        let poiCellNib: UINib? = UINib(nibName: "PointOfInterestCell", bundle: nil)
        collectionView?.register(poiCellNib, forCellWithReuseIdentifier: poiCellReuseIdentifier)

        observerToken = PointOfInterest.addObserver(poiObserver)

        let doubleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapCollectionView))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        doubleTapRecognizer.delaysTouchesBegan = true
        //collectionView?.addGestureRecognizer(doubleTapRecognizer)
    }

    @objc func didDoubleTapCollectionView(recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            let doubleTapPoint = recognizer.location(in: collectionView)
            if  let path = collectionView?.indexPathForItem(at: doubleTapPoint),
                let doubleTappedCell = collectionView?.cellForItem(at: path) as? PointOfInterestCell,
                let imageView = doubleTappedCell.backgroundView as? UIImageView {
                switch imageView.contentMode {
                case .scaleToFill:
                    imageView.contentMode = .scaleAspectFit
                case .scaleAspectFit:
                    imageView.contentMode = .scaleAspectFill
                default:
                    imageView.contentMode = .scaleToFill
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationItem.hidesBackButton = true
        
        if let pageVC = pageViewController {
            pageVC.navigationItem.leftBarButtonItems = self.navigationItem.leftBarButtonItems
            pageVC.navigationItem.rightBarButtonItems = self.navigationItem.rightBarButtonItems
        }
    }

    func poiObserver(event: Firebase.Observer.Event, key: Firebase.Observer.Key, poi: PointOfInterest) {
        guard Thread.current.isMainThread else { fatalError("Poi observer not on main thread: \(Thread.current)") }
        switch event {
        case .added:
            pointsOfInterest.append(poi)
            pointsOfInterest = pointsOfInterest.sorted { $0.location.coordinate.latitude > $1.location.coordinate.latitude } // northmost first
        case .updated:
            pointsOfInterest = pointsOfInterest.filter { $0 != poi }
            pointsOfInterest.append(poi)
        case .removed:
            pointsOfInterest = pointsOfInterest.filter { $0 != poi }
        }

        collectionView?.reloadData()
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if let pageVC = pageViewController {
            pageVC.switchPages(sender: self)
            return false
        }
        return true
    }

    @IBAction func unwind(_ segue:UIStoryboardSegue) {
    }
}

extension ListViewController : UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pointsOfInterest.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let poi = pointsOfInterest[indexPath.item]
        
        let poiCell = collectionView.dequeueReusableCell(withReuseIdentifier: poiCellReuseIdentifier, for: indexPath) as! PointOfInterestCell
        
        let imageView = UIImageView(image: poi.image)
        imageView.contentMode = .scaleAspectFill
        let scrollView = UIScrollView()
        scrollView.addSubview(imageView)
        poiCell.backgroundView = scrollView
        poiCell.nameLabel.text = poi.name
        poiCell.distanceLabel.text = poi.distanceToUserText
        
        return poiCell
    }
    
}

extension ListViewController : UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let scrollView = cell.backgroundView, let imageView = scrollView.subviews[0] as? UIImageView {
            imageView.frame.size = imageView.image!.aspectFill(in: scrollView.frame.size)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        let frame = collectionView.cellForItem(at: indexPath)!.frame
        DetailView.present(poi: pointsOfInterest[indexPath.item], startingFrom: frame)
    }
}

extension ListViewController : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(UIScreen.main.bounds.width), height: CGFloat(120))
    }
}
