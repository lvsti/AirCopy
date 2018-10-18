//
//  AppDelegate.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 27..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Cocoa
import AirCopyFramework


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var menuController: MenuController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        statusItem.image = #imageLiteral(resourceName: "statusicon")
        statusItem.image?.isTemplate = true
        statusItem.menu = NSMenu(title: statusItem.title!)
        
        NSMenu.setMenuBarVisible(false)
        
        menuController = MenuController(
            menu: statusItem.menu!,
            service: AirCopyService.sharedService,
            browser: AirCopyServiceBrowser(),
            pasteboardController: PasteboardController()
        )

        AirCopyService.sharedService.startAcceptingConnections()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        AirCopyService.sharedService.stopAcceptingConnections()
    }
    
}

