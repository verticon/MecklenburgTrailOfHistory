//
//  DetailViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 12/30/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
//

import UIKit

class DetailView : UIView {

    private let textView = UITextView()
    private let imageView = UIImageView()
    private let modalViewController = UIViewController()


    public init(poi: PointOfInterest) {
        super.init(frame: CGRect.zero)

        backgroundColor = UIColor(white: 1, alpha: 0.5)
        addGestureRecognizer(UITapGestureRecognizer(target:self, action: #selector(dismiss(_:))))
        
        // AFAIK If no other action is taken then the image view will size itself to the image, even if this results in a size larger than the window.
        imageView.image = poi.image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(imageView)

        let textAttributes = [NSStrokeColorAttributeName : UIColor.black,
                              NSForegroundColorAttributeName : UIColor.white,
                              NSStrokeWidthAttributeName : -3.0] as [String : Any]
        textView.attributedText = NSAttributedString(string: poi.description, attributes: textAttributes)
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.font = UIFont.init(name: "Helvetica", size: 18)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(textView)

        // Here we constrain the image view to not exceed the size of its superview; this causes the scaleAspectFit contentMode to "kick in".
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: self.widthAnchor, multiplier: 1.0),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: self.heightAnchor, multiplier: 1.0),
            ])

        modalViewController.modalPresentationStyle = .overCurrentContext
        modalViewController.modalTransitionStyle = .crossDissolve
        modalViewController.view = self
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("Init with coder not implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        
        textView.center = center // Hmmmm ...

        // At this point the image view's size will have been set and wee can use it to siz the text view.
        textView.bounds.size = aspectFitImageSize()
    }

    func present() {
        let window = UIApplication.shared.delegate!.window!!
        let presentingViewController = window.visibleViewController!
        presentingViewController.present(modalViewController, animated: false, completion: nil)
    }
    
    private func aspectFitImageSize() -> CGSize {
        let imageSize = imageView.image!.size
        let widthRatio = imageView.bounds.size.width / imageSize.width
        let heightRatio = imageView.bounds.size.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        let scaledImageWidth = scale * imageSize.width
        let scaledImageHeight = scale * imageSize.height
        return CGSize(width: scaledImageWidth, height: scaledImageHeight)
    }

    @objc private func dismiss(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            modalViewController.dismiss(animated: false, completion: nil)
        }
    }
    
    private func describe(view: UIView, indent: String) {
        func describe(_ view: UIView, _ indent: String) {
            print("\(indent)\(view)")
            view.subviews.forEach() { describe($0, indent + "\t") }
        }
        print("\n")
        describe(view, indent)
    }
}
