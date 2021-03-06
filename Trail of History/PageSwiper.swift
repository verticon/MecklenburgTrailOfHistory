//
//  PageSwiper.swift
//  Trail of History
//
//  Created by Robert Vaessen on 1/17/18.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import UIKit

class PageSwiper: UIView {

    enum Direction {
        case left
        case right
    }
    
    var direction: Direction = .left {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let context = UIGraphicsGetCurrentContext()!
        var x: CGFloat = direction == .left ? 1 : bounds.maxX - 1
        var deltaY: CGFloat = 3.0
        for _ in 1...3 {
            context.move(to: CGPoint(x: x, y: center.y - deltaY))
            context.addLine(to: CGPoint(x: x, y: center.y + deltaY))

            x += direction == .left ? 2 : -2
            deltaY += 3
        }
        context.setStrokeColor(UIColor.tohTerracotaColor.cgColor)
        context.setLineWidth(1)
        context.strokePath()
    }
}
