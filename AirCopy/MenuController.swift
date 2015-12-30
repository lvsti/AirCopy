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


class MenuController: NSObject, ServiceBrowserDelegate, NSMenuDelegate, AirCopyServiceDelegate {
    // dependencies
    private let _menu: NSMenu
    private let _service: AirCopyService
    private let _browser: ServiceBrowser
    private let _pasteboardController: PasteboardController

    // state
    private let _previewItem: NSMenuItem
    private let _servicesHeaderItem: NSMenuItem
    private var _serviceItems: [NSMenuItem]
    private let _incomingHeaderItem: NSMenuItem
    private var _incomingItems: [NSMenuItem]
    private let _otherItems: [NSMenuItem]
    
    init(menu: NSMenu, service: AirCopyService, browser: ServiceBrowser, pasteboardController: PasteboardController) {
        _menu = menu
        _service = service
        _browser = browser
        _pasteboardController = pasteboardController
        
        _previewItem = NSMenuItem(title: "Clipboard is empty")
        _servicesHeaderItem = NSMenuItem(title: "No nearby devices")
        _serviceItems = []
        _incomingHeaderItem = NSMenuItem(title: "Received clipboards")
        _incomingItems = []
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
//        _incomingItems
        
        _menu.addItem(NSMenuItem.separatorItem())
        for item in _otherItems {
            _menu.addItem(item)
        }
    }

    func updateServiceItemsWithServices(services: [NSNetService]) {
        _serviceItems.removeAll(keepCapacity: true)
        
        for service in services {
            let menuItem = NSMenuItem(title: service.name) { [unowned self] _ in
                guard let pasteboardItem = self._pasteboardController.currentItem else {
                    return
                }
                let reps = self._pasteboardController.representationsForItem(pasteboardItem)
                self._service.sendPasteboardItemsWithRepresentations([reps], toNetService: service)
            }
            
            menuItem.indentationLevel = 1
            _serviceItems.append(menuItem)
        }
        
        _servicesHeaderItem.title = services.count > 0 ? "Send clipboard contents to:" : "No nearby devices"
    }
    
    func updatePreviewItemWithView(view: NSView?) {
        _previewItem.view = view
    }
    
    // MARK: - from NSMenuDelegate:
    
    func menuNeedsUpdate(menu: NSMenu) {
        _pasteboardController.updateLocalItems()
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
    
    // MARK: - from AirCopyServiceDelegate:
    
    func airCopyService(service: AirCopyService,
        didReceivePasteboardItemsWithRepresentations items: [[(String, NSData)]],
        fromNetService netService: NSNetService) {
    }
    
}
