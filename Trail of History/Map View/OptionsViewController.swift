//
//  OptionsViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 9/9/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
//

import UIKit
import MapKit

protocol OptionsViewControllerDelegate: class {
    var mapType: MKMapType { get set }

    func zoomToTrail()
    func zoomToUser()
    func zoomToBoth()
}

class OptionsViewController: UITableViewController {

    // On the storyboard, the table view's static cells have been given
    // reuse identifiers equal to the raw values of the CellIdentifier enum.
    enum CellIdentifier: String {
        case Standard
        case Satellite
        case Hybrid
        
        case ZoomToTrail
        case ZoomToUser
        case ZoomToBoth

        var mapType: MKMapType? {
            get {
                switch(self) {
                case .Standard: return MKMapType.standard
                case .Satellite: return MKMapType.satellite
                case .Hybrid: return MKMapType.hybrid
                default: return nil
                }
            }
        }
        
        // Find the table cell whose reuse identifier is equal to the raw value of self
        func getCell(_ table: UITableView) -> UITableViewCell? {
            for section in 0 ..< table.numberOfSections {
                for row in 0 ..< table.numberOfRows(inSection: section) {
                    let cell = table.cellForRow(at: IndexPath(row: row, section: section))!
                    if self == CellIdentifier(rawValue: cell.reuseIdentifier!) { return cell }
                }
            }
            return nil
        }
    }
    
    enum UserDefaultsKey: String {
        case mapType
        case callouts
    }

    static func initialize(delegate: OptionsViewControllerDelegate) {
        let userDefaults = UserDefaults.standard
        
        if let mapTypeName = userDefaults.string(forKey: UserDefaultsKey.mapType.rawValue), let mapType = CellIdentifier(rawValue: mapTypeName)?.mapType {
            delegate.mapType = mapType
        }
    }

    weak var delegate: OptionsViewControllerDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()

        switch delegate.mapType {
        case .standard:
            CellIdentifier.Standard.getCell(tableView)?.accessoryType = .checkmark
        case .satellite:
            CellIdentifier.Satellite.getCell(tableView)?.accessoryType = .checkmark
        case .hybrid:
            CellIdentifier.Hybrid.getCell(tableView)?.accessoryType = .checkmark
        default:
            break
        }

        tableView.backgroundColor = UIColor.tohGreyishBrownTwoColor
        tableView.tableHeaderView?.backgroundColor = UIColor.tohTerracotaColor
        if let count = tableView.tableHeaderView?.subviews.count, count > 0, let button = tableView.tableHeaderView?.subviews[0] as? UIButton {
            button.setTitleColor(UIColor.tohGreyishBrownTwoColor, for: .normal)
            button.borderColor = UIColor.tohGreyishBrownTwoColor
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.backgroundView?.backgroundColor = UIColor.tohGreyishBrownTwoColor
            header.textLabel?.backgroundColor = UIColor.clear
            header.textLabel?.textColor = UIColor.tohTerracotaColor
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor.tohDullYellowColor
        cell.tintColor = UIColor.tohTerracotaColor
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let cell = tableView.cellForRow(at: indexPath)!
        let identifier = CellIdentifier(rawValue: cell.reuseIdentifier!)!

        switch identifier {
        // Map Types
        case .Standard: fallthrough
        case .Satellite: fallthrough
        case .Hybrid:
            if cell.accessoryType == .none { // Only take action if the user taps one other than the one that is currently
                // Check the selected cell and uncheck the others.
                cell.accessoryType = .checkmark
                for id in [CellIdentifier.Standard, CellIdentifier.Satellite, CellIdentifier.Hybrid] where id != identifier {
                    id.getCell(tableView)?.accessoryType = .none
                }
                delegate.mapType = identifier.mapType!
                UserDefaults.standard.set(identifier.rawValue, forKey: UserDefaultsKey.mapType.rawValue)
            }

        // Map Actions
        case .ZoomToTrail:
            delegate.zoomToTrail()
        case .ZoomToUser:
            delegate.zoomToUser()
        case .ZoomToBoth:
            delegate.zoomToBoth()
        }
        
        cell.isSelected = false // Don't leave it highlighted
    }

    @IBAction func dismiss(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension OptionsViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
/*
    func presentationController(controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        let navigationController = UINavigationController(rootViewController: controller.presentedViewController)
        let doneButton = UIBarButtonItem(title: "Done", style: .Done, target: self, action: #selector(dismiss))
        navigationController.topViewController!.navigationItem.rightBarButtonItem = doneButton
        return navigationController
    }
    
    func dismiss() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
*/
}
