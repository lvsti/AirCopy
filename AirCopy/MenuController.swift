//
//  MenuController.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 29..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation
import AppKit


class MenuController: ServiceBrowserDelegate {
    private let _browser: ServiceBrowser
    
    private let _menu: NSMenu
    private var _menuObserver: NSObjectProtocol!

    private let _pasteboardItem: NSMenuItem
    
    private let _servicesHeaderItem: NSMenuItem
    private var _serviceItems: [NSMenuItem]

    private let _otherItems: [NSMenuItem]
    
    init(menu: NSMenu) {
        _menu = menu
        _pasteboardItem = NSMenuItem(title: "Clipboard is empty")
        
        _servicesHeaderItem = NSMenuItem(title: "")
        _serviceItems = []
        
        _otherItems = [
            NSMenuItem(title: "Quit AirCopy", keyEquivalent: "q") { _ in
                NSApplication.sharedApplication().terminate(nil)
            }
        ]

        _browser = ServiceBrowser()
        _browser.delegate = self

        let onMenuOpenNotification = { [unowned self] (_: NSNotification) in
            self.updateMenu()
            
            self._browser.start()
        }
        
        _menuObserver = NSNotificationCenter.defaultCenter().addObserverForName(NSMenuDidBeginTrackingNotification,
            object: _menu,
            queue: nil,
            usingBlock: onMenuOpenNotification)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(_menuObserver)
    }
    
    func updateMenu() {
        _menu.removeAllItems()
        
        _menu.addItem(_pasteboardItem)
        _menu.addItem(NSMenuItem.separatorItem())

        _menu.addItem(_servicesHeaderItem)
        for item in _serviceItems {
            _menu.addItem(item)
        }
        _menu.addItem(NSMenuItem.separatorItem())
        
        for item in _otherItems {
            _menu.addItem(item)
        }
    }

    func updateServiceItemsWithServices(services: [NSNetService]) {
        _serviceItems.removeAll(keepCapacity: true)
        
        for service in services {
            let item = NSMenuItem(title: service.name, keyEquivalent: "") { _ in
                
            }
            item.representedObject = service
            item.indentationLevel = 1
            _serviceItems.append(item)
        }
        
        _servicesHeaderItem.title = services.count > 0 ? "Send clipboard contents to:" : "No nearby devices"
    }
    
    func updatePasteboardSectionWithView(view: NSView?) {
        _pasteboardItem.view = view
    }
    
    // MARK: - from ServiceBrowserDelegate:
    
    func serviceBrowserDidUpdateServices(browser: ServiceBrowser) {
        updateServiceItemsWithServices(browser.services)
    }
    
}
