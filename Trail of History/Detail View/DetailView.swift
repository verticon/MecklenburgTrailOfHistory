//
//  DetailViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 12/30/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
//

import AVFoundation
import UIKit
import AVKit
import WebKit
import SafariServices
import VerticonsToolbox

class DetailView : UIView, AVPlayerViewControllerDelegate {

    class PresentingAnimator : NSObject, UIViewControllerAnimatedTransitioning {
        
        func transitionDuration(using: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 2.5
        }
        
        func animateTransition(using context: UIViewControllerContextTransitioning) {
            
            let toViewController = context.viewController(forKey: UITransitionContextViewControllerKey.to)!
            let finalFrameForVC = context.finalFrame(for: toViewController)

            // Move the detail view off of the screen.
            toViewController.view.frame = finalFrameForVC.offsetBy(dx: 0, dy: UIScreen.main.bounds.size.height)
            context.containerView.addSubview(toViewController.view)
            
            let animations = {
                // Animate the detail view back onto the screen.
                toViewController.view.frame = finalFrameForVC
            }
            UIView.animate(withDuration: transitionDuration(using: context), delay: 0.0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.0, options: .curveLinear, animations: animations) { _ in
                context.completeTransition(!context.transitionWasCancelled)
            }
        }
    }
    
    class DismissingAnimator : NSObject, UIViewControllerAnimatedTransitioning {
        
        func transitionDuration(using: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 1
        }
        
        func animateTransition(using context: UIViewControllerContextTransitioning) {
            
            let fromViewController = context.viewController(forKey: UITransitionContextViewControllerKey.from)!
            let containerView = context.containerView

            let snapshotView = fromViewController.view.snapshotView(afterScreenUpdates: false)!
            containerView.addSubview(snapshotView)
            fromViewController.view.removeFromSuperview()

            let animations = {
                snapshotView.frame = fromViewController.view.frame.insetBy(dx: fromViewController.view.frame.size.width / 2, dy: fromViewController.view.frame.size.height / 2)
            }
            UIView.animate(withDuration: transitionDuration(using: context), animations: animations) { _ in
                context.completeTransition(!context.transitionWasCancelled) }
        }
    }
    
    private class TransitionController : UIViewController, UIViewControllerTransitioningDelegate {

        private let presentingAnimator = PresentingAnimator()
        func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            return presentingAnimator
        }

        private let dismissingAnimator = DismissingAnimator()
        func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            return dismissingAnimator
        }
    }
    
    static func present(poi: PointOfInterest) {
        let window = UIApplication.shared.delegate!.window!!
        let presenter = window.visibleViewController!

        let barHeight = presenter.navigationController?.navigationBar.frame.maxY ?? UIApplication.shared.statusBarFrame.height
        
        let controller = TransitionController()
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = controller
        
        controller.view = DetailView(poi: poi, presenter: presenter, controller: controller, barHeight: barHeight)
        
        presenter.present(controller, animated: true, completion: nil)
    }
    
    private let poiId : String
    private let textView = UITextView()
    private let imageView = UIImageView()
    private let movieButton = UIButton()
    private let inset: CGFloat = 16
    private var observerToken: Any!
    private let movieUrl: URL?
    private let barHeight: CGFloat
    private let controller: UIViewController

    private init(poi: PointOfInterest, presenter: UIViewController, controller: UIViewController, barHeight: CGFloat) {
        poiId = poi.id
        movieUrl = poi.movieUrl
        self.controller = controller
        self.barHeight = barHeight

        super.init(frame: CGRect.zero)

        backgroundColor = UIColor(white: 1, alpha: 0.5) // Allow the underlying view to be seen through a white haze.
        addGestureRecognizer(UITapGestureRecognizer(target:self, action: #selector(dismiss(_:))))
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        textView.isEditable = false
        //textView.isSelectable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textColor = UIColor.lightGray
        textView.backgroundColor = UIColor(red: 248.0/255.0, green: 241.0/255.0, blue: 227.0/255.0, alpha: 1) // Safari's tan, reader view color.
        addSubview(textView)

        movieButton.translatesAutoresizingMaskIntoConstraints = false
        movieButton.setImage(#imageLiteral(resourceName: "PlayMovieButton"), for: .normal)
        movieButton.addTarget(self, action: #selector(playMovie), for: .touchUpInside)
        addSubview(movieButton)
        
        update(using: poi)

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
            
            movieButton.rightAnchor.constraint(equalTo: imageView.rightAnchor, constant: -8),
            movieButton.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -8),
            movieButton.widthAnchor.constraint(equalToConstant: 32),
            movieButton.heightAnchor.constraint(equalToConstant: 32),
            ])

        observerToken = PointOfInterest.addObserver(poiListener, dispatchQueue: DispatchQueue.main)
    }

    func poiListener(poi: PointOfInterest, event: PointOfInterest.Event) {
        
        if poi.id == poiId {
            switch event {
            case .updated:
                update(using: poi)
                self.setNeedsDisplay()
            case .removed:
                controller.dismiss(animated: false, completion: nil)
            default:
                break
            }
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("Init with coder not implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
 
        let imageSize = imageView.aspectFitImageSize()
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

        // Expand the height of the text view to the height of its content, up to but not exceeding the available space
        if textView.contentSize.height + imageSize.height > availableVerticalSpace {
            textView.frame.size.height = availableVerticalSpace - imageSize.height
        }
        else {
            textView.frame.size.height = textView.contentSize.height
        }


        let totalHeight = imageSize.height + textView.frame.height

        // Position the image vertically
        let currImageTop = self.center.y - imageSize.height/2
        let newImageTop = self.center.y - totalHeight/2 + barHeight/2
        imageView.frame.origin.y -= currImageTop - newImageTop

        // Position the text view vertically
        let currTextTop = textView.frame.origin.y
        let newTextTop = newImageTop + imageSize.height
        textView.frame.origin.y -= currTextTop - newTextTop
        textView.contentOffset = CGPoint.zero

 
        // Place the movie button in the lower right corner of the image
        if movieUrl != nil {
            movieButton.frame.origin.x = textView.frame.maxX - (movieButton.frame.width + 8)
            movieButton.frame.origin.y = textView.frame.minY - (movieButton.frame.height + 8)
        }
        else {
            movieButton.isHidden = true
        }

        // TODO: Improve the shadow
        // Create a shadow around the combined image and text views
        let shadowView = UIView(frame: CGRect(x: inset, y: newImageTop, width: imageSize.width, height: totalHeight))
        let radius: CGFloat = shadowView.frame.width / 2.0 //change it to .height if you need spread for height
        let shadowPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 2.1 * radius, height: shadowView.frame.height))
        //Change 2.1 to amount of spread you need and for height replace the code for height
        shadowView.layer.cornerRadius = 2
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 0.5, height: 0.4)  //Here you control x and y
        shadowView.layer.shadowOpacity = 0.5
        shadowView.layer.shadowRadius = 5.0 // This controls the blur
        shadowView.layer.masksToBounds =  false
        shadowView.layer.shadowPath = shadowPath.cgPath
        self.insertSubview(shadowView, at: 0)

        //info("After")
        //print("\tShadow View: \(shadowView.frame)")
    }

    private func update(using poi: PointOfInterest) {
        let window = UIApplication.shared.delegate!.window!!

        // AFAIK If no other action is taken then the image view will size itself to the image, even if this results in a size larger than the window.
        imageView.image = poi.image
        imageView.contentMode = poi.image.size.width > (window.frame.width - 2*inset) || poi.image.size.height > (window.frame.height - 2*inset) ? .scaleAspectFit : .scaleAspectFill

        /*
         let textAttributes = [NSStrokeColorAttributeName : UIColor.black,
         NSForegroundColorAttributeName : UIColor.white,
         NSStrokeWidthAttributeName : -3.0] as [String : Any]
         */
        let link = "Learn More ..."
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let text = NSMutableAttributedString(string: "\(poi.name)\n\n\(poi.description)\n\n\(poi.meckncGovUrl == nil ? "" : link)", attributes: [
            NSAttributedStringKey.font : UIFont(name: "Helvetica", size: 18)!,
            NSAttributedStringKey.paragraphStyle : style
            ])
        text.addAttributes([NSAttributedStringKey.font : UIFont(name: "HelveticaNeue-Bold", size: 18)!], range: NSRange(location: 0, length: poi.name.count))
        if let url = poi.meckncGovUrl {
            text.addAttributes([NSAttributedStringKey.link : url], range: NSRange(location: text.length - link.count, length: link.count))
        }
        textView.attributedText = text
    }

    
    @objc private func playMovie() {
        let player = AVPlayer(url: movieUrl!)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        controller.present(playerViewController, animated: true) {
            playerViewController.player!.play()
        }
    }

    func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: Error) {
        print("There was a playback error: \(error)")
    }

    @objc private func dismiss(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            dismiss()
        }
    }
    
    private func dismiss() {
        _ = PointOfInterest.removeObserver(token: observerToken)
        controller.dismiss(animated: true, completion: nil)
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
