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
    private let controller = UIViewController()
    private let presenter: UIViewController

    private let inset: CGFloat = 16

    public init(poi: PointOfInterest) {
        let window = UIApplication.shared.delegate!.window!!
        presenter = window.visibleViewController!

        super.init(frame: CGRect.zero)

        backgroundColor = UIColor(white: 1, alpha: 0.5)
        addGestureRecognizer(UITapGestureRecognizer(target:self, action: #selector(dismiss(_:))))
        
        // AFAIK If no other action is taken then the image view will size itself to the image, even if this results in a size larger than the window.
        imageView.image = poi.image
        imageView.contentMode = poi.image.size.width > (window.frame.width - 2*inset) || poi.image.size.height > (window.frame.height - 2*inset) ? .scaleAspectFit : .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(imageView)

        /*
        let textAttributes = [NSStrokeColorAttributeName : UIColor.black,
                              NSForegroundColorAttributeName : UIColor.white,
                              NSStrokeWidthAttributeName : -3.0] as [String : Any]
        textView.attributedText = NSAttributedString(string: poi.description, attributes: textAttributes)
        */
        textView.text = poi.description
        textView.isEditable = false
        textView.font = UIFont.init(name: "Helvetica", size: 18)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(textView)

        // Here we constrain the image view to not exceed the size of its superview; this causes the scaleAspectFit contentMode to "kick in".
        NSLayoutConstraint.activate([
            imageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            imageView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: inset),
            imageView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -inset),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: self.heightAnchor),

            textView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            textView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            textView.widthAnchor.constraint(equalTo: imageView.widthAnchor),
            textView.heightAnchor.constraint(equalTo: imageView.heightAnchor),
            ])

        controller.modalPresentationStyle = .overCurrentContext
        controller.modalTransitionStyle = .crossDissolve
        controller.view = self
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("Init with coder not implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
 
        let imageSize = aspectFitImageSize()
        let barHeight = presenter.navigationController?.navigationBar.frame.maxY ?? UIApplication.shared.statusBarFrame.height
        let availableVerticalSpace = self.frame.height - (barHeight + 2*inset)

        func info(_ header: String) {
            print("\n\(header)")
            print("\tRoot View: \(self.frame)")
            print("\tImage View: \(imageView.frame)")
            print("\tText View: \(textView.frame)")
            print("\tImage Size: \(imageSize)")
            print("\tText Content Size: \(textView.contentSize)")
        }

        //info("Before")


        // What we want to accomplish is that the image (which might be shorter that the image view) sits on top
        // of the text view and that the space above the image (not counting the bars) be equal to the space below
        // the text view. If there is a sufficient amount of text then the above/below spaces will go to almost zero
        // (we will enforce an inset) and scrolling of the text will "kick in"
        //
        // Note: The code assumes that the image and text view are initially centered in their super view.
        // This should have be assurred by the contraints that were applied by the initializer.

        
        var newTextFrame = textView.frame
        newTextFrame.size.height = textView.contentSize.height
        if newTextFrame.height + imageSize.height > availableVerticalSpace {
            newTextFrame.size.height = availableVerticalSpace - imageSize.height
        }
        textView.frame = newTextFrame
        
        let totalHeight = imageSize.height + textView.frame.height

        let currImageTop = self.center.y - imageSize.height/2
        let newImageTop = self.center.y - totalHeight/2 + barHeight/2
        imageView.frame.origin.y -= currImageTop - newImageTop

        let currTextTop = textView.frame.origin.y
        let newTextTop = newImageTop + imageSize.height
        textView.frame.origin.y -= currTextTop - newTextTop
 
        let shadowView = UIView(frame: CGRect(x: inset, y: newImageTop, width: imageSize.width, height: totalHeight))
        let radius: CGFloat = shadowView.frame.width / 2.0 //change it to .height if you need spread for height
        let shadowPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 2.1 * radius, height: shadowView.frame.height))
        //Change 2.1 to amount of spread you need and for height replace the code for height
        shadowView.layer.cornerRadius = 2
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 0.5, height: 0.4)  //Here you control x and y
        shadowView.layer.shadowOpacity = 0.5
        shadowView.layer.shadowRadius = 5.0 //Here your control your blur
        shadowView.layer.masksToBounds =  false
        shadowView.layer.shadowPath = shadowPath.cgPath
        self.insertSubview(shadowView, at: 0)

        //info("After")
        //print("\tShadow View: \(shadowView.frame)")
    }

    func present() {
        presenter.present(controller, animated: false, completion: nil)
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
            controller.dismiss(animated: false, completion: nil)
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
