//
//  PageSwiper.swift
//  Trail of History
//
//  Created by Robert Vaessen on 1/17/18.
//  Copyright © 2018 rvaessen.com. All rights reserved.
//

import UIKit

class PageSwiper: UIView {

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let context = UIGraphicsGetCurrentContext()!
        var x: CGFloat = 1.0
        var deltaY: CGFloat = 3.0
        for _ in 1...3 {
            context.move(to: CGPoint(x: x, y: center.y - deltaY))
            context.addLine(to: CGPoint(x: x, y: center.y + deltaY))

            x += 2
            deltaY += 3
        }
        if let color = backgroundColor { context.setStrokeColor(color.darken().cgColor) }
        else { context.setStrokeColor(UIColor.black.cgColor) }
        context.setLineWidth(1)
        context.strokePath()
    }
}
