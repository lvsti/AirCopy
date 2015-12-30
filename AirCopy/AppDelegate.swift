//
//  AppDelegate.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 27..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var menuController: MenuController!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let statusBar = NSStatusBar.systemStatusBar()
        statusItem = statusBar.statusItemWithLength(NSVariableStatusItemLength)
        
        statusItem.title = "AirCopy"
        statusItem.menu = NSMenu(title: statusItem.title!)
        
        NSMenu.setMenuBarVisible(false)
        
        menuController = MenuController(
            menu: statusItem.menu!,
            service: AirCopyService.sharedService,
            browser: ServiceBrowser(),
            pasteboardController: PasteboardController()
        )

        AirCopyService.sharedService.startAcceptingConnections()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        AirCopyService.sharedService.stopAcceptingConnections()
    }
    
}

