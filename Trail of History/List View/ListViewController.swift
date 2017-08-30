//
//  DummyListTableViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 8/24/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
//

import UIKit

class ListViewController: UICollectionViewController {

    fileprivate let poiCellReuseIdentifier = "PointOfInterestCell"
    fileprivate var pointsOfInterest = [PointOfInterest]()
    private var listenerToken: PointOfInterest.Database.ListenerToken!

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.titleView = UIView.fromNib("Title")
        navigationItem.titleView?.backgroundColor = UIColor.clear // It was set to an opaque color in the NIB so that the white, text images would be visible in the Interface Builder.
        navigationItem.rightBarButtonItem?.tintColor = UIColor.tohTerracotaColor() // TODO: We should be able to access the TOH custom colors in the Interface Builder

        let poiCellNib: UINib? = UINib(nibName: "PointOfInterestCell", bundle: nil)
        collectionView?.register(poiCellNib, forCellWithReuseIdentifier: poiCellReuseIdentifier)

        listenerToken = PointOfInterest.Database.instance.registerListener(poiListener, dispatchQueue: DispatchQueue.main)

        let doubleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapCollectionView))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        doubleTapRecognizer.delaysTouchesBegan = true
        //collectionView?.addGestureRecognizer(doubleTapRecognizer)
    }
    
    func didDoubleTapCollectionView(recognizer: UITapGestureRecognizer) {
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

    func poiListener(poi: PointOfInterest, event: PointOfInterest.Database.Event) {
        
        switch event {
        case .added:
            pointsOfInterest.append(poi)
        case .updated:
            pointsOfInterest = pointsOfInterest.filter { $0.id != poi.id }
            pointsOfInterest.append(poi)
        case .removed:
            pointsOfInterest = pointsOfInterest.filter { $0.id != poi.id }
        }

        pointsOfInterest = pointsOfInterest.sorted { $0.coordinate.longitude < $1.coordinate.longitude }
        
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
        poiCell.backgroundView = imageView
        poiCell.nameLabel.text = poi.name
        poiCell.distanceLabel.text = poi.distanceToUser()
        
        return poiCell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        DetailView(poi: pointsOfInterest[indexPath.item]).present()
        collectionView.deselectItem(at: indexPath, animated: false)
    }

    @IBAction func unwind(_ segue:UIStoryboardSegue) {
    }

}

extension ListViewController : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(UIScreen.main.bounds.width), height: CGFloat(120))
    }
}
