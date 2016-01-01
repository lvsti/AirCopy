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
let kSearchStatusChangeTreshold: NSTimeInterval = 1.0

class MenuController: NSObject, ServiceBrowserDelegate, NSMenuDelegate, AirCopyServiceDelegate {
    // dependencies
    private let _menu: NSMenu
    private let _service: AirCopyService
    private let _browser: ServiceBrowser
    private let _pasteboardController: PasteboardController

    // state
    private var _menuItems: [NSMenuItem]
    private var _searchStatusMenuItem: NSMenuItem!
    private var _receivedStatusMenuItem: NSMenuItem!
    private var _searchStartDate: NSDate?
    private var _visibleServiceCount: Int
    private var _visibleReceivedCount: Int
    
    init(menu: NSMenu, service: AirCopyService, browser: ServiceBrowser, pasteboardController: PasteboardController) {
        _menu = menu
        _service = service
        _browser = browser
        _pasteboardController = pasteboardController
        
        _menuItems = []
        _visibleServiceCount = 0
        _visibleReceivedCount = 0
        
        super.init()
        
        _browser.delegate = self
        _menu.delegate = self
        _service.delegate = self
    }
    
    private func rebuildMenu() {
        _menuItems.removeAll(keepCapacity: true)
        
        _visibleServiceCount = _browser.services.count
        _visibleReceivedCount = _pasteboardController.receivedItems.count

        _menuItems.append(menuItemForPasteboardPreview())
        
        _menuItems.append(NSMenuItem.separatorItem())
        _searchStatusMenuItem = NSMenuItem(title: titleForSearchStatusMenuItem())
        _menuItems.append(_searchStatusMenuItem)
        for service in _browser.services {
            _menuItems.append(menuItemForService(service))
        }
        
        _menuItems.append(NSMenuItem.separatorItem())
        _receivedStatusMenuItem = NSMenuItem(title: titleForReceivedStatusMenuItem())
        _menuItems.append(_receivedStatusMenuItem)

        let sortedKeys = _pasteboardController.receivedItems.keys.sort(<)
        for key in sortedKeys {
            let pbItem = _pasteboardController.receivedItems[key]!
            _menuItems.append(menuItemForReceivedPasteboardItem(pbItem, withKey: key))
        }
        
        _menuItems.append(NSMenuItem.separatorItem())
        _menuItems.append(NSMenuItem(title: "Quit AirCopy", keyEquivalent: "q") { _ in
            NSApplication.sharedApplication().terminate(nil)
        })
    }
    
    private func renderMenu() {
        _menu.removeAllItems()
        for item in _menuItems {
            _menu.addItem(item)
        }
    }

    private func menuItemForPasteboardPreview() -> NSMenuItem {
        let menuItem = NSMenuItem(title: "Clipboard is empty")
        _pasteboardController.updateCurrentItem()
        menuItem.view = _pasteboardController.viewForItem(_pasteboardController.currentItem,
            constrainedToSize: CGSize(width: kDefaultWidth, height: kMaxItemHeight))
        
        return menuItem
    }
    
    private func titleForSearchStatusMenuItem() -> String {
        if _browser.isSearching {
            return "Searching..."
        }
        
        return _visibleServiceCount > 0 ? "Send clipboard contents to:" : "No nearby devices"
    }
    
    private func titleForReceivedStatusMenuItem() -> String {
        return _visibleReceivedCount > 0 ? "Received clipboards:" : "No received clipboards"
    }
    
    private func menuItemForService(service: NSNetService) -> NSMenuItem {
        let menuItem = NSMenuItem(title: service.name) { [unowned self] _ in
            guard let pasteboardItem = self._pasteboardController.currentItem else {
                return
            }
            let reps = self._pasteboardController.representationsForItem(pasteboardItem)
            self._service.sendPasteboardItemsWithRepresentations([reps], toNetService: service)
        }
        
        menuItem.indentationLevel = 1
        
        return menuItem
    }
    
    private func menuItemForReceivedPasteboardItem(pbItem: NSPasteboardItem, withKey key: String) -> NSMenuItem {
        let previewItem = NSMenuItem(title: "<clipboard preview>")
        previewItem.view = _pasteboardController.viewForItem(pbItem,
            constrainedToSize: CGSize(width: kDefaultWidth, height: kMaxItemHeight))
        
        let applyItem = NSMenuItem(title: "Apply")  { [unowned self] _ in
            self._pasteboardController.makeCurrentReceivedItemWithKey(key)
            self.rebuildMenu()
        }
        let deleteItem = NSMenuItem(title: "Delete")  { [unowned self] _ in
            self._pasteboardController.deleteReceiveItemWithKey(key)
            self.rebuildMenu()
        }
        
        let submenu = NSMenu(title: key)
        submenu.addItem(previewItem)
        submenu.addItem(applyItem)
        submenu.addItem(deleteItem)
        
        let menuItem = NSMenuItem(title: key)
        menuItem.submenu = submenu
        menuItem.indentationLevel = 1

        return menuItem
    }
    
    func updateMenu() {
        guard _menu.highlightedItem != nil else {
            rebuildMenu()
            renderMenu()
            _menu.update()
            return
        }
        
        _searchStatusMenuItem.title = titleForSearchStatusMenuItem()
        _menu.itemChanged(_searchStatusMenuItem)

        _receivedStatusMenuItem.title = titleForReceivedStatusMenuItem()
        _menu.itemChanged(_receivedStatusMenuItem)
    }

    // MARK: - from NSMenuDelegate:
    
    func menuNeedsUpdate(menu: NSMenu) {
        guard menu == _menu else {
            return
        }

        _searchStartDate = NSDate()
        _browser.start()
        rebuildMenu()
        renderMenu()
    }
    
    // MARK: - from ServiceBrowserDelegate:
    
    func serviceBrowserDidUpdateServices(browser: ServiceBrowser) {
        let elapsed = NSDate().timeIntervalSinceDate(_searchStartDate!)
        if elapsed > kSearchStatusChangeTreshold {
            updateMenu()
        }
        else {
            let timer = NSTimer(timeInterval: kSearchStatusChangeTreshold - elapsed,
                target: self,
                selector: "updateMenu",
                userInfo: nil,
                repeats: false)
            NSRunLoop.currentRunLoop().addTimer(timer, forMode: NSEventTrackingRunLoopMode)
        }
    }
    
    // MARK: - from AirCopyServiceDelegate:
    
    func airCopyService(service: AirCopyService,
        didReceivePasteboardItemsWithRepresentations items: [[(String, NSData)]],
        fromNetService netService: NSNetService) {
        // currently only the first item is used
        guard let reps = items.first else {
            return
        }
        
        _pasteboardController.addReceivedItemWithRepresentations(reps, forKey: netService.name)
        
        NSRunLoop.currentRunLoop().performSelector("updateMenu", target: self, argument: nil, order: 0, modes: [NSEventTrackingRunLoopMode])
    }
    
}
