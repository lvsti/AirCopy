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

    @IBOutlet weak var statusMenu: NSMenu!
    var statusItem: NSStatusItem!
    var currentPasteboardItems: [NSPasteboardItem] = []
    var menuController: MenuController!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        AirCopyService.sharedService.start()

        let statusBar = NSStatusBar.systemStatusBar()
        statusItem = statusBar.statusItemWithLength(NSVariableStatusItemLength)
        
        statusItem.title = "AirCopy"
        statusItem.menu = statusMenu
        
        NSMenu.setMenuBarVisible(false)
        
        menuController = MenuController(menu: statusMenu, browser: ServiceBrowser(), pasteboardController: PasteboardController())
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        AirCopyService.sharedService.stop()
    }
    
}

