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

private class PresentingAnimator : NSObject, UIViewControllerAnimatedTransitioning {
    
    private let initiatingFrame: CGRect // The frame of the element that was tapped to initiate the Detail View presentation
    private let imageFrame: CGRect // The final size of the Detail View's image view subview.
    private let image: UIImage
    private var toViewController: UIViewController!

    init(initiatingFrame: CGRect, imageFrame: CGRect, image: UIImage) {
        self.initiatingFrame = initiatingFrame
        self.imageFrame = imageFrame
        self.image = image
        super.init()
    }

    func transitionDuration(using: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 1.5
    }
    
    func animateTransition(using context: UIViewControllerContextTransitioning) {
 
        self.toViewController = context.viewController(forKey: UITransitionContextViewControllerKey.to)!
        let finalFrame = context.finalFrame(for: self.toViewController)

        // Start by displaying the image, completely transparent, in the initiating frame. The image will fill the frame
        // and its aspect ratio will be preserved. UIImageView's default behavior is to center the image. A UIScrollView
        // is used so as to display the upper left portion, hopefully all of the width (i.e. the statue's upper torso).
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        let size = image.aspectFill(in: initiatingFrame.size)
        imageView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let scrollView = UIScrollView(frame: initiatingFrame)
        scrollView.backgroundColor = .orange // A visual clue that things are misalighend, i.e. we should see no orange
        scrollView.addSubview(imageView)
        scrollView.alpha = 0
        // The scroll view will end up on top of the detail view so we need to be able to tap it as well
        scrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss(_:))))
        context.containerView.addSubview(scrollView)
        
        let animations = {
            // Turn the image opaque and then move/resize it from the initiating frame to the final frame of the Detail View's image subview.
            UIView.addKeyframe(withRelativeStartTime: 0,   relativeDuration: 1/2) { scrollView.alpha = 1 }
            UIView.addKeyframe(withRelativeStartTime: 1/2, relativeDuration: 1/2) {
                scrollView.frame = self.imageFrame
                let size = self.image.aspectFill(in: self.imageFrame.size)
                imageView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            }
        }
        UIView.animateKeyframes(withDuration: transitionDuration(using: context) * 2 / 3, delay: 0, animations: animations) { _ in
            // Reduce the Detail View's height so that only its image view subview is showing. The detail view's frame should
            // then exactly match the frame of the ScrollView/ImageView that was presented by the first part of the anumation.
            self.toViewController.view.clipsToBounds = true
            let frame = self.toViewController.view.frame
            self.toViewController.view.frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: self.imageFrame.size.height)
            context.containerView.addSubview(self.toViewController.view)

            // Expand the Detail View's size to reveal its text subview.
            UIView.animate(withDuration: self.transitionDuration(using: context) / 3, delay: 0, animations: { self.toViewController.view.frame = finalFrame }) { _ in
                context.completeTransition(!context.transitionWasCancelled)
            }
        }
    }

    @objc func dismiss(_ gestureRecognizer: UITapGestureRecognizer) {
        toViewController.dismiss(animated: true, completion: nil)
    }

}

private class DismissingAnimator : NSObject, UIViewControllerAnimatedTransitioning {
    
    private let initiatingFrame: CGRect
    private let imageFrame: CGRect

    init(initiatingFrame: CGRect, imageFrame: CGRect) {
        self.initiatingFrame = initiatingFrame
        self.imageFrame = imageFrame
        super.init()
    }
    
    func transitionDuration(using: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 1.5
    }
    
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        
        let fromViewController = context.viewController(forKey: UITransitionContextViewControllerKey.from)!

        let frame = fromViewController.view.frame
        let imageFrame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: self.imageFrame.origin.y + self.imageFrame.size.height)
        // Begin by rolling up the text view until only the image shows
        UIView.animate(withDuration: transitionDuration(using: context) / 3, animations: { fromViewController.view.frame = imageFrame }) { _ in
            // Remove the remainder (the image) of the detail view, thus revealing the scroll view that was created be the presenting animator
            fromViewController.view.removeFromSuperview()
            
            let scrollView = context.containerView.subviews[0] as! UIScrollView
            let imageView = scrollView.subviews[0] as! UIImageView
            let animations = {
                // Now move the scroll view back to the initiating frame.
                UIView.addKeyframe(withRelativeStartTime: 0,   relativeDuration: 1/2) {
                    scrollView.frame = self.initiatingFrame
                    let size = imageView.image!.aspectFill(in: self.initiatingFrame.size)
                    imageView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                }
                // Finally fade the scroll view to transparent so as to reveal the initiating frame.
                UIView.addKeyframe(withRelativeStartTime: 1/2, relativeDuration: 1/2) { scrollView.alpha = 0  }
            }
            UIView.animateKeyframes(withDuration: self.transitionDuration(using: context) * 2 / 3, delay: 0, animations: animations) { _ in
                context.completeTransition(!context.transitionWasCancelled)
            }
        }
    }
}

private class TransitionController : NSObject, UIViewControllerTransitioningDelegate {

    private let initiatingFrame: CGRect
    private let image: UIImage

    private let targetController: DetailViewController
    private let presentingAnimator: UIViewControllerAnimatedTransitioning
    private let dismissingAnimator: UIViewControllerAnimatedTransitioning
    
    init(targetController: DetailViewController, initiatingFrame: CGRect, imageFrame: CGRect, image: UIImage) {
        self.targetController = targetController
        self.initiatingFrame = initiatingFrame
        self.image = image
        self.presentingAnimator = PresentingAnimator(initiatingFrame: initiatingFrame, imageFrame: imageFrame, image: image)
        self.dismissingAnimator = DismissingAnimator(initiatingFrame: initiatingFrame, imageFrame: imageFrame)
        super.init()
    }

    private var setupNeeded = true
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // At this point we can be sure that the target controller's view (the detail view) has been set and thus that we can add a gesture recognizer to it.
        // If we were to perform this setup in the init method then we would impose a condition upon the sequence of steps in the static present method.
        if setupNeeded {
            setupNeeded = false
            targetController.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:))))
        }
        
        return presentingAnimator
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismissingAnimator
    }
    
    @objc func tapHandler(_ gestureRecognizer: UITapGestureRecognizer) {
        targetController.dismiss(animated: true, completion: nil)
    }
}

private class DetailViewController : UIViewController {
    var transitionController: TransitionController! { // Store a strong reference (since controller.transitioningDelegate is weak)
        didSet {
            transitioningDelegate = transitionController
        }
    }
    
    var detailView: DetailView! // Store a strong reference (since controller.transitioningDelegate is weak)
}

/*
 1) The image view mode will be aspect fill.
 2) The image view width will be set equal to the detail view's width
    and the height will be set so as to maintain the aspect ratio.
 3) The image view will be contained by a scroll view whose size will
    be equal the image view's size but with the restriction that the
    height may not exceed 1/2 of the detail view's height
 4) Thus we will see all of the image's width and some or all of the
    image's height
*/

class DetailView : UIView, AVPlayerViewControllerDelegate {
 
    static func present(poi: PointOfInterest, startingFrom: CGRect) {
        let window = UIApplication.shared.delegate!.window!!
        let presenter = window.visibleViewController!

        let barHeight = presenter.navigationController?.navigationBar.frame.maxY ?? UIApplication.shared.statusBarFrame.height
        
        let controller = DetailViewController()
        //controller.view.backgroundColor = UIColor(white: 1, alpha: 0.5) // Allow the underlying view to be seen through a white haze.

        let detailView = DetailView(poi: poi, controller: controller, barHeight: barHeight)

        controller.detailView = detailView

        controller.transitionController = TransitionController(targetController: controller, initiatingFrame: startingFrom.offsetBy(dx: 0, dy: barHeight), imageFrame: detailView.imageViewFrame(), image: poi.image)

        controller.modalPresentationStyle = .custom // TODO: reconsider the effect of this
        presenter.present(controller, animated: true, completion: nil)
    }
    
    private let poiId : String
    fileprivate let statueImageView = UIImageView()
    fileprivate let imageScrollView = UIScrollView()
    private let movieButton = UIButton()
    private let nameLabel = UILabel()
    private let descriptionTextView = UITextView()
    private let learnMoreUrl: URL?
    private let learnMoreButton = UIButton()
    private let inset: CGFloat = 16
    private var observerToken: Any!
    private let movieUrl: URL?
    private let barHeight: CGFloat
    private let controller: UIViewController
    private let scrollViewHeightConstraint: NSLayoutConstraint

    private init(poi: PointOfInterest, controller: UIViewController, barHeight: CGFloat) {
        self.controller = controller
        self.barHeight = barHeight

        poiId = poi.id
        movieUrl = poi.movieUrl
        learnMoreUrl = poi.meckncGovUrl

        scrollViewHeightConstraint = imageScrollView.heightAnchor.constraint(equalToConstant: 0)

        super.init(frame: detailViewFrame())

        self.borderWidth = 1
        self.cornerRadius = 4
        self.borderColor = .tohTerracotaColor
        self.backgroundColor = .tohGreyishBrownTwoColor
        self.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(self)

        update(using: poi)

        let size = imageViewSize()
        statueImageView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        statueImageView.contentMode = .scaleAspectFill
        imageScrollView.addSubview(statueImageView)
        imageScrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageScrollView)

        nameLabel.textAlignment = .center
        nameLabel.font = UIFont(name: "HoeflerText-Black", size: 18)!
        nameLabel.font = descriptionTextView.font?.withSize(18) // Why is this line necessary? The size parameter to UIFont's initializer has no effect.
        nameLabel.textColor = .tohTerracotaColor
        nameLabel.backgroundColor = .tohGreyishBrownTwoColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        descriptionTextView.textAlignment = .justified
        descriptionTextView.isEditable = false
        descriptionTextView.isSelectable = false
        descriptionTextView.font = UIFont(name: "HoeflerText-Regular", size: 18)!
        descriptionTextView.font = descriptionTextView.font?.withSize(18) // Why is this line necessary? The size parameter to UIFont's initializer has no effect.
        descriptionTextView.textColor = .white
        descriptionTextView.backgroundColor = .tohGreyishBrownTwoColor
        descriptionTextView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(descriptionTextView)

        if movieUrl != nil {
            movieButton.setImage(#imageLiteral(resourceName: "PlayMovieButton"), for: .normal)
            movieButton.addTarget(self, action: #selector(playMovie), for: .touchUpInside)
        }
        else {
            movieButton.isHidden = true
        }
        movieButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(movieButton)

        if learnMoreUrl != nil { learnMoreButton.setTitle("Learn more ...", for: .normal) }
        else { learnMoreButton.isHidden = true }
        learnMoreButton.translatesAutoresizingMaskIntoConstraints = false
        learnMoreButton.addTarget(self, action: #selector(learnMore(_:)), for: .touchUpInside)
        learnMoreButton.setTitleColor(.tohTerracotaColor, for: .normal)
        learnMoreButton.backgroundColor = .tohGreyishBrownTwoColor
        addSubview(learnMoreButton)

        // TODO: Improve the shadow
        /*
        let shadowView = UIView(frame: frame)
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
        */


        NSLayoutConstraint.activate([
            // TODO: Understand why it is necessary to contrain the detail view itself (the first 4 constraints)
            self.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: barHeight + inset),
            self.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            self.widthAnchor.constraint(equalToConstant: frame.width),
            self.heightAnchor.constraint(equalToConstant: frame.height),
            
            imageScrollView.topAnchor.constraint(equalTo: self.topAnchor),
            imageScrollView.leftAnchor.constraint(equalTo: self.leftAnchor),
            imageScrollView.rightAnchor.constraint(equalTo: self.rightAnchor),
            scrollViewHeightConstraint,
            
            learnMoreButton.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            learnMoreButton.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            nameLabel.topAnchor.constraint(equalTo: imageScrollView.bottomAnchor, constant: 4),
            nameLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),

            descriptionTextView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            descriptionTextView.bottomAnchor.constraint(equalTo: learnMoreButton.topAnchor),
            descriptionTextView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            descriptionTextView.widthAnchor.constraint(equalTo: imageScrollView.widthAnchor),
            
            movieButton.rightAnchor.constraint(equalTo: imageScrollView.rightAnchor, constant: -8),
            movieButton.bottomAnchor.constraint(equalTo: imageScrollView.bottomAnchor, constant: -8),
            movieButton.widthAnchor.constraint(equalToConstant: 32),
            movieButton.heightAnchor.constraint(equalToConstant: 32),
            ])

        observerToken = PointOfInterest.addObserver(poiListener, dispatchQueue: DispatchQueue.main)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("Init with coder not implemented")
    }
    
    deinit {
        _ = PointOfInterest.removeObserver(token: observerToken)
    }

    @objc func learnMore(_ sender: UIButton) {
        if let link = learnMoreUrl { UIApplication.shared.open(link) }
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

    public override func layoutSubviews() {
        let height = imageViewSize().height
        let limit = detailViewFrame().size.height / 2
        scrollViewHeightConstraint.constant = height > limit ? limit : height
        super.layoutSubviews()
    }

    private func update(using poi: PointOfInterest) {

        // AFAIK If no other action is taken then the image view will size itself to the image, even if this results in a size larger than the window.
        statueImageView.image = poi.image

        nameLabel.text = poi.name

        /*
        let justified = NSMutableParagraphStyle()
        justified.alignment = NSTextAlignment.justified
        let text = NSMutableAttributedString(string: "\(poi.name)\n\n\(poi.description)\n", attributes: [
            NSAttributedStringKey.font : UIFont(name: "HoeflerText-Regular", size: 18)!,
            NSAttributedStringKey.paragraphStyle : justified,
            NSAttributedStringKey.foregroundColor : UIColor.white
            ])
        let centered = NSMutableParagraphStyle()
        centered.alignment = NSTextAlignment.center
        text.addAttributes([
            NSAttributedStringKey.font : UIFont(name: "HoeflerText-Black", size: 18)!,
            NSAttributedStringKey.paragraphStyle : centered,
            NSAttributedStringKey.foregroundColor : UIColor.tohTerracotaColor
            ], range: NSRange(location: 0, length: poi.name.count))
        descriptionTextView.attributedText = text
         */

        descriptionTextView.text = poi.description
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

    func detailViewFrame() -> CGRect {
        let size = UIScreen.main.bounds.size
        let frame = CGRect(x: 0, y: barHeight, width: size.width, height: size.height - barHeight)
        return frame.insetBy(dx: inset, dy: inset)
    }

    func imageViewSize() -> CGSize {
        let imageSize = statueImageView.image!.size
        let imageViewWidth = detailViewFrame().width
        let imageViewHeight = (imageSize.height / imageSize.width) * imageViewWidth
        return CGSize(width: imageViewWidth, height: imageViewHeight)
    }
    
    func imageViewFrame() -> CGRect {
        let frame = detailViewFrame()
        let size = imageViewSize()
        return CGRect(x: frame.origin.x, y: frame.origin.y, width: size.width, height: size.height)
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
