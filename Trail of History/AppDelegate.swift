//
//  AppDelegate.swift
//  Trail of History
//
//  Created by Mark Flowers on 3/14/16.
//  Copyright © 2016 CLT Mobile. All rights reserved.
//

import UIKit
import CoreData
import Firebase
import FirebaseDatabase
import VerticonsToolbox


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        print("\(applicationName) started - \(LocalTime.text)")

        //_ = Firebase.connection.addListener(self, handlerClassMethod: AppDelegate.firebaseConnectionEventHandler)

        //listFonts()

        //printInfo()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
    }

    func listFonts() {
        var list = ""
        for family in UIFont.familyNames {
            list += "\(family)\n"
            for font in UIFont.fontNames(forFamilyName: family) {
                list += "\t\(font)\n"
            }
        }
        print(list)
    }

    private func printInfo() {
        print("Stdout = \(stdout)")
        print("Trail of history file name = \(String(describing: tohFileName))")
    }

    private func firebaseConnectionEventHandler(event: Firebase.ConnectionEvent) {
        switch event {
        case .established:
            alertUser(title: applicationName, body: "A database connection has been established.")
        case .failed:
            alertUser(title: applicationName, body: "A database connection could not be established; locally cached data, if any, will be used")
            break
        case .lost:
            alertUser(title: applicationName, body: "The database connection has been lost.")
            break
        }
    }
    
}

