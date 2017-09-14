//
//  RootViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 9/8/17.
//  Copyright © 2017 Robert Vaessen. All rights reserved.
//

import UIKit

class PageViewController: UIViewController {

    var mapViewController: MapViewController!
    var listViewController: ListViewController!
    let pageViewController: UIPageViewController = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal, options: nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.titleView = UIView.fromNib("Title")
        navigationItem.titleView?.backgroundColor = UIColor.clear // It was set to an opaque color in the NIB so that the white, text images would be visible in the Interface Builder.

        let listStoryboard = UIStoryboard(name: "List", bundle: nil)
        listViewController = (listStoryboard.instantiateViewController(withIdentifier: "List View Controller") as! ListViewController)
        listViewController.pageViewController = self
        
        let mapStoryboard = UIStoryboard(name: "Map", bundle: nil)
        mapViewController = (mapStoryboard.instantiateViewController(withIdentifier: "Map View Controller") as! MapViewController)
        mapViewController.pageViewController = self

        pageViewController.setViewControllers([listViewController], direction: .forward, animated: false, completion: nil)

        navigationItem.rightBarButtonItems = listViewController.navigationItem.rightBarButtonItems
        navigationItem.rightBarButtonItem?.tintColor = UIColor.tohTerracotaColor()

        addChildViewController(pageViewController)
        view.addSubview(pageViewController.view)

        pageViewController.dataSource = self
        
        // We do not want taps in the List View to cause page swicthes.
        pageViewController.gestureRecognizers.forEach {
            if $0 is UITapGestureRecognizer {
                pageViewController.view.removeGestureRecognizer($0)
            }
        }

        pageViewController.didMove(toParentViewController: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func switchPages(sender: UIViewController) {
        if sender === listViewController {
            pageViewController.setViewControllers([mapViewController], direction: .forward, animated: false, completion: nil)
        }
        else {
            pageViewController.setViewControllers([listViewController], direction: .forward, animated: false, completion: nil)
        }
    }
}

extension PageViewController : UIPageViewControllerDataSource {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        return viewController === mapViewController ? listViewController : nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        return viewController === listViewController ? mapViewController : nil
    }
}
