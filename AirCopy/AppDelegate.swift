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
    var trampoline: ActionTrampoline<NSMenuItem>!
    var menuController: MenuController!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        AirCopyService.sharedService.start()

        trampoline = ActionTrampoline<NSMenuItem> { [weak self] (item: NSMenuItem) in
            NSLog("menu item clicked: %@", item)
            
            let service = item.representedObject as! NSNetService

            var os: NSOutputStream? = nil
            guard
                service.getInputStream(nil, outputStream: &os),
                let outputStream = os where os != nil
            else {
                return
            }
            
            outputStream.open()

            let pbItems = self!.currentPasteboardItems
            let transfer = OutboundTransfer(outputStream: outputStream)
            
            itemLoop:
            for pbItem in pbItems {
                NSLog("types: %@", pbItem.types)
                for type in pbItem.types {
                    guard let itemData = pbItem.dataForType(type) else {
                        continue
                    }
                    do {
                        try transfer.transferItemWithType(type, data: itemData)
                    }
                    catch {
                        break itemLoop
                    }
                }
            }

            outputStream.close()

        }

        let statusBar = NSStatusBar.systemStatusBar()
        statusItem = statusBar.statusItemWithLength(NSVariableStatusItemLength)
        
        statusItem.title = "AirCopy"
        statusItem.menu = statusMenu
        
        NSMenu.setMenuBarVisible(false)
        
        menuController = MenuController(menu: statusMenu)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        AirCopyService.sharedService.stop()
    }
    
}

