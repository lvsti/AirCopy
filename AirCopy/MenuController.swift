//
//  MenuController.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 29..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation
import AppKit

let kDefaultWidth: CGFloat = 250
let kMaxItemHeight: CGFloat = 250


class MenuController: NSObject, ServiceBrowserDelegate, NSMenuDelegate {
    // dependencies
    private let _browser: ServiceBrowser
    private let _pasteboardController: PasteboardController
    private let _menu: NSMenu

    // state
    private let _previewItem: NSMenuItem
    private let _servicesHeaderItem: NSMenuItem
    private var _serviceItems: [NSMenuItem]
    private let _otherItems: [NSMenuItem]
    
    init(menu: NSMenu, browser: ServiceBrowser, pasteboardController: PasteboardController) {
        _menu = menu
        _browser = browser
        _pasteboardController = pasteboardController
        
        _previewItem = NSMenuItem(title: "Clipboard is empty")
        _servicesHeaderItem = NSMenuItem(title: "No nearby devices")
        _serviceItems = []
        _otherItems = [
            NSMenuItem(title: "Quit AirCopy", keyEquivalent: "q") { _ in
                NSApplication.sharedApplication().terminate(nil)
            }
        ]
        
        super.init()
        
        _browser.delegate = self
        _menu.delegate = self
    }
    
    func rebuildMenu() {
        _menu.removeAllItems()
        
        _menu.addItem(_previewItem)
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
            let item = NSMenuItem(title: service.name) { _ in
                
            }
            item.representedObject = service
            item.indentationLevel = 1
            _serviceItems.append(item)
        }
        
        _servicesHeaderItem.title = services.count > 0 ? "Send clipboard contents to:" : "No nearby devices"
    }
    
    func updatePreviewItemWithView(view: NSView?) {
        _previewItem.view = view
    }
    
    // MARK: - from NSMenuDelegate:
    
    func menuNeedsUpdate(menu: NSMenu) {
        _pasteboardController.update()
        let pasteboardPreview = _pasteboardController.viewForItem(_pasteboardController.currentItem,
            constrainedToSize: CGSize(width: kDefaultWidth, height: kMaxItemHeight))
        updatePreviewItemWithView(pasteboardPreview)
        
        rebuildMenu()
        
        _browser.start()
    }
    
    // MARK: - from ServiceBrowserDelegate:
    
    func serviceBrowserDidUpdateServices(browser: ServiceBrowser) {
        updateServiceItemsWithServices(browser.services)
        rebuildMenu()
    }
    
}
