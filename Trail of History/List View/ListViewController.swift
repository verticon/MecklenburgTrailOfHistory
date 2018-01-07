//
//  DummyListTableViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 8/24/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
//

import UIKit
import VerticonsToolbox

class ListViewController: UICollectionViewController {

    var pageViewController: PageViewController?

    fileprivate let poiCellReuseIdentifier = "PointOfInterestCell"
    fileprivate var pointsOfInterest = [PointOfInterest]()
    private var observerToken: Any!

    override func viewDidLoad() {
        super.viewDidLoad()

        //navigationItem.titleView = UIView.fromNib("Title")
        //navigationItem.titleView?.backgroundColor = UIColor.clear // It was set to an opaque color in the NIB so that the white, text images would be visible in the Interface Builder.
        navigationItem.rightBarButtonItem?.tintColor = UIColor.tohTerracotaColor // TODO: We should be able to access the TOH custom colors in the Interface Builder

        let poiCellNib: UINib? = UINib(nibName: "PointOfInterestCell", bundle: nil)
        collectionView?.register(poiCellNib, forCellWithReuseIdentifier: poiCellReuseIdentifier)

        observerToken = PointOfInterest.addObserver(poiListener, dispatchQueue: DispatchQueue.main)

        let doubleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapCollectionView))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        doubleTapRecognizer.delaysTouchesBegan = true
        collectionView?.addGestureRecognizer(doubleTapRecognizer)
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

    func poiListener(poi: PointOfInterest, event: PointOfInterest.Event) {

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

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pointsOfInterest.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
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

    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let scrollView = cell.backgroundView, let imageView = scrollView.subviews[0] as? UIImageView {
            imageView.frame.size = scrollView.frame.size
            imageView.frame.size = imageView.aspectFillImageSize()
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        DetailView.present(poi: pointsOfInterest[indexPath.item])
        collectionView.deselectItem(at: indexPath, animated: false)
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

extension ListViewController : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(UIScreen.main.bounds.width), height: CGFloat(120))
    }
}
