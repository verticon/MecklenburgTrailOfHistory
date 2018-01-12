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
    
    private let startingRect: CGRect
    
    init(startingRect: CGRect) {
        self.startingRect = startingRect
        super.init()
    }
    
    func transitionDuration(using: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 5.0
    }
    
    func animateTransition2(using context: UIViewControllerContextTransitioning) {
        
        let toViewController = context.viewController(forKey: UITransitionContextViewControllerKey.to)!
        let finalFrameForVC = context.finalFrame(for: toViewController)
        
        // Move the detail view off of the screen.
        toViewController.view.frame = startingRect
        toViewController.view.clipsToBounds = true
        context.containerView.addSubview(toViewController.view)
        
        let animations = {
            // Animate the detail view back onto the screen.
            //toViewController.view.frame = finalFrameForVC
            let deltaX = finalFrameForVC.origin.x - self.startingRect.origin.x
            let deltaY = finalFrameForVC.origin.y - self.startingRect.origin.y
            let deltaWidth = self.startingRect.width - finalFrameForVC.width
            let deltaHeight = self.startingRect.height - finalFrameForVC.height
            toViewController.view.frame = toViewController.view.frame.insetBy(dx: deltaWidth / 2, dy: deltaHeight / 2).offsetBy(dx: deltaX, dy: deltaY)
        }
        UIView.animate(withDuration: transitionDuration(using: context), delay: 0.0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.0, options: .curveLinear, animations: animations) { _ in
            context.completeTransition(!context.transitionWasCancelled)
        }
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

private class DismissingAnimator : NSObject, UIViewControllerAnimatedTransitioning {
    
    class InteractionController : UIPercentDrivenInteractiveTransition {
        
        var interactionInProgress = false
        private var shouldCompleteTransition = false
        private weak var targetController: UIViewController!
        
        init(targetController: UIViewController) {
            super.init()
            self.targetController = targetController
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
            targetController.view.addGestureRecognizer(recognizer)
        }
        
        @objc func handleGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view!.superview!)
            var progress = (translation.x / 200)
            progress = CGFloat(fminf(fmaxf(Float(progress), 0.0), 1.0))
            
            switch gestureRecognizer.state {
            case .began:
                interactionInProgress = true
                targetController.dismiss(animated: true, completion: nil)
                report("Gesture began")
            case .changed:
                shouldCompleteTransition = progress > 0.5
                update(progress)
                report("Gesture changed")
            case .cancelled:
                interactionInProgress = false
                cancel()
                report("Gesture cancelled")
            case .ended:
                interactionInProgress = false
                if shouldCompleteTransition { finish() }
                else { cancel() }
                report("Gesture ended")
            default:
                break
            }
        }
        
        func report(_ text: String) {
            print("\(text)")
        }
    }
    
    private let endingRect: CGRect
    
    init(endingRect: CGRect) {
        self.endingRect = endingRect
        super.init()
    }
    
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
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
}


private class TransitionController : NSObject, UIViewControllerTransitioningDelegate {
    
    private let presentingAnimator: UIViewControllerAnimatedTransitioning
    private let dismissingAnimator: UIViewControllerAnimatedTransitioning
    private let targetController: DetailViewController
    private let interactionController: DismissingAnimator.InteractionController? = nil
    
    init(targetController: DetailViewController, initiatingRect: CGRect) {
        self.targetController = targetController
        self.presentingAnimator = PresentingAnimator(startingRect: initiatingRect)
        self.dismissingAnimator = DismissingAnimator(endingRect: initiatingRect)
        super.init()
    }
    
    private var setupNeeded = true
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // At this point we can be sure that the target controller's view (the detail view) has been set and thus that we can add a gesture recognizer to it.
        // If we were to perform this setup in the init method then we impose a condition upon the sequence of steps in the static present method.
        if setupNeeded {
            setupNeeded = false
            
            // There is a problem with the interaction controller: the gesture recognizer produces a begin event,
            // immediately followed by a cancel event. I have not been able to understand why the cancel occurs.
            // My code responds to begin event by dismissing the target view controller. If I comment out that
            // line then the cancel does not occur.
            //interactionController = DismissingAnimator.InteractionController(targetController: targetController)
            
            // Until I can work on the interaction controller, let's go with a tap to initiate the dismissal.
            targetController.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:))))
        }
        
        return presentingAnimator
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismissingAnimator
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionController
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

class DetailView : UIView, AVPlayerViewControllerDelegate {
 
    static func present(poi: PointOfInterest, startingFrom: CGRect) {
        let window = UIApplication.shared.delegate!.window!!
        let presenter = window.visibleViewController!

        let barHeight = presenter.navigationController?.navigationBar.frame.maxY ?? UIApplication.shared.statusBarFrame.height
        
        let controller = DetailViewController()
        //controller.view.backgroundColor = UIColor(white: 1, alpha: 0.5) // Allow the underlying view to be seen through a white haze.

        controller.detailView = DetailView(poi: poi, controller: controller, barHeight: barHeight)

        let initiatingRect = startingFrom.offsetBy(dx: 0, dy: barHeight)
        controller.transitionController = TransitionController(targetController: controller, initiatingRect: initiatingRect) // The target controller's view must have already been set

        controller.modalPresentationStyle = .custom
        presenter.present(controller, animated: true, completion: nil)
    }
    
    private let poiId : String
    private let imageView = UIImageView()
    private let movieButton = UIButton()
    private let textView = UITextView()
    private let learnMoreUrl: URL?
    private let learnMoreButton = UIButton()
    private let inset: CGFloat = 16
    private var observerToken: Any!
    private let movieUrl: URL?
    private let barHeight: CGFloat
    private let controller: UIViewController
    private let imageViewHeightConstraint: NSLayoutConstraint

    private init(poi: PointOfInterest, controller: UIViewController, barHeight: CGFloat) {
        self.controller = controller
        self.barHeight = barHeight

        poiId = poi.id
        movieUrl = poi.movieUrl
        learnMoreUrl = poi.meckncGovUrl

        var frame = UIScreen.main.bounds
        frame.size.height -= barHeight
        frame.origin.y += barHeight
        frame = frame.insetBy(dx: inset, dy: inset)

       imageViewHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: frame.size.height)

        super.init(frame: frame)

        self.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(self)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        textView.isEditable = false
        textView.isSelectable = false
        textView.textColor = UIColor.lightGray
        textView.backgroundColor = UIColor(red: 248.0/255.0, green: 241.0/255.0, blue: 227.0/255.0, alpha: 1) // Safari's tan, reader view color.
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

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

        update(using: poi)

        NSLayoutConstraint.activate([
            self.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: barHeight),
            self.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            self.widthAnchor.constraint(equalToConstant: frame.width),
            self.heightAnchor.constraint(equalToConstant: frame.height),
            
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.leftAnchor.constraint(equalTo: self.leftAnchor),
            imageView.rightAnchor.constraint(equalTo: self.rightAnchor),
            imageViewHeightConstraint,
            
            learnMoreButton.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            learnMoreButton.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            textView.topAnchor.constraint(equalTo: imageView.bottomAnchor),
            textView.bottomAnchor.constraint(equalTo: learnMoreButton.bottomAnchor),
            textView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            textView.widthAnchor.constraint(equalTo: imageView.widthAnchor),
            
            movieButton.rightAnchor.constraint(equalTo: imageView.rightAnchor, constant: -8),
            movieButton.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -8),
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
 
        // Set the image view's height constraint equal to the height to which the image will be scaled.
        imageView.bounds = self.bounds
        imageViewHeightConstraint.constant = imageView.contentMode == .scaleAspectFit ? imageView.aspectFitImageSize().height : imageView.aspectFillImageSize().height

        super.layoutSubviews()
    }

    private func update(using poi: PointOfInterest) {

        // AFAIK If no other action is taken then the image view will size itself to the image, even if this results in a size larger than the window.
        imageView.image = poi.image
        imageView.contentMode = poi.image.size.width > self.bounds.size.width || poi.image.size.height > self.bounds.size.height ? .scaleAspectFit : .scaleAspectFill

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
    
    private func describe(view: UIView, indent: String) {
        func describe(_ view: UIView, _ indent: String) {
            print("\(indent)\(view)")
            view.subviews.forEach() { describe($0, indent + "\t") }
        }
        print("\n")
        describe(view, indent)
    }
}
