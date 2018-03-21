//
//  Trail_of_History_UI_Tests.swift
//  Trail of History UI Tests
//
//  Created by Robert Vaessen on 3/19/18.
//  Copyright © 2018 rvaessen.com. All rights reserved.
//

import XCTest

class Trail_of_History_UI_Tests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let app = XCUIApplication()
        app.navigationBars["Trail_of_History.PageView"].children(matching: .button).element(boundBy: 1).tap()
        app.otherElements["Thomas Spratt & King Haigler, lat 35.22006, long -80.83041"].tap()
        app.otherElements["Captain Jack, lat 35.21687, long -80.8327"].tap()
        app.collectionViews.cells.otherElements.containing(.staticText, identifier:"Captain Jack").buttons["ShowDetail"].tap()
    }
    
}
