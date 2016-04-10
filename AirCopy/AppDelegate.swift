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

    var statusItem: NSStatusItem!
    var menuController: MenuController!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let statusBar = NSStatusBar.systemStatusBar()
        statusItem = statusBar.statusItemWithLength(NSVariableStatusItemLength)
        
        statusItem.image = NSImage(named: "statusicon")
        statusItem.image?.template = true
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

