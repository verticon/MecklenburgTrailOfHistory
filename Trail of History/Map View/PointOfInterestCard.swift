//
//  PointOfInterestCell.swift
//  Trail of History
//
//  Created by Robert Vaessen on 9/3/16.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import UIKit

class PointOfInterestCard: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    
    var poi: PointOfInterest!
}
