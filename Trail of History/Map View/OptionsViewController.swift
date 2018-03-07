//
//  OptionsViewController.swift
//  Trail of History
//
//  Created by Robert Vaessen on 9/9/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
//

import UIKit
import MapKit
import VerticonsToolbox

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

        case EmailLogFiles

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

    static func getMapType() -> MKMapType {
        guard   let mapTypeName = UserDefaults.standard.string(forKey: UserDefaultsKey.mapType.rawValue),
                let mapType = CellIdentifier(rawValue: mapTypeName)?.mapType else { return MKMapType.standard }

        return mapType
    }

    weak var delegate: OptionsViewControllerDelegate!
    private let alpha: CGFloat = 0.5

    private var emailAddress: String?
    private var observer: Firebase.Observer? = nil

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

        view.backgroundColor = UIColor.clear

        tableView.tableHeaderView?.backgroundColor = UIColor.tohTerracotaColor.withAlphaComponent(alpha)
        if let count = tableView.tableHeaderView?.subviews.count, count > 0, let button = tableView.tableHeaderView?.subviews[0] as? UIButton {
            button.setTitleColor(UIColor.tohGreyishBrownTwoColor, for: .normal)
            button.borderColor = UIColor.tohGreyishBrownTwoColor
        }

        observer = Firebase.Observer(path: "Support") { event, key, properties in
            self.emailAddress = (properties["emailAddress"] as! String)
            self.observer?.cancel()
            print("Options View: support email address is \(self.emailAddress ?? "<unknown>")")
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerFooter = view as? UITableViewHeaderFooterView {
            headerFooter.backgroundView?.backgroundColor = UIColor.tohGreyishBrownTwoColor.withAlphaComponent(0.8)
            headerFooter.textLabel?.backgroundColor = UIColor.clear
            headerFooter.textLabel?.textColor = UIColor.tohDullYellowColor
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let headerFooter = view as? UITableViewHeaderFooterView {
            headerFooter.backgroundView?.backgroundColor = UIColor.tohGreyishBrownTwoColor.withAlphaComponent(0.8)
            headerFooter.textLabel?.backgroundColor = UIColor.clear
            headerFooter.textLabel?.text = ""
        }
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor.tohDullYellowColor.withAlphaComponent(alpha)
        cell.textLabel?.backgroundColor = UIColor.clear
        cell.tintColor = UIColor.tohTerracotaColor.withAlphaComponent(alpha)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let cell = tableView.cellForRow(at: indexPath)!
        let identifier = CellIdentifier(rawValue: cell.reuseIdentifier!)!

        switch identifier {
        // Map Types
        case .Standard: fallthrough
        case .Satellite: fallthrough
        case .Hybrid:
            if cell.accessoryType == .none { // Only take action if the user taps one other than the one that is currently checked
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

        case .EmailLogFiles:
            _ = Email.sender.send(to: [emailAddress ?? ""], subject: "\(applicationName) Log Files", message: "", attachments: FileLogger.instance?.package() ?? [:], presenter: self)
        }
        
        // Don't leave it highlighted
        //cell.isSelected = false  // If the cell is scrolled out of sight (off top or bottom) and then back into view, then its appearence changes back to highlighted???
        tableView.deselectRow(at: indexPath, animated: false) // This works as desired.
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func dismiss(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension OptionsViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController) {
        popoverPresentationController.backgroundColor = UIColor.clear
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
