//
//  MenuController.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 29..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation
import AppKit
import AirCopyFramework
import Cutis

let kDefaultWidth: CGFloat = 250
let kMaxItemHeight: CGFloat = 250
let kSearchStatusChangeTreshold: TimeInterval = 1.0

class MenuController: NSObject, NSMenuDelegate, AirCopyServiceBrowserDelegate, AirCopyServiceDelegate {
    // dependencies
    private let menu: NSMenu
    private let service: AirCopyService
    private let browser: AirCopyServiceBrowser
    private let pasteboardController: PasteboardController

    // state
    private var menuItems: [NSMenuItem]
    private var searchStatusMenuItem: NSMenuItem!
    private var receivedStatusMenuItem: NSMenuItem!
    private var searchStartDate: Date?
    private var visibleServiceCount: Int
    private var visibleReceivedCount: Int
    
    init(menu: NSMenu, service: AirCopyService, browser: AirCopyServiceBrowser, pasteboardController: PasteboardController) {
        self.menu = menu
        self.service = service
        self.browser = browser
        self.pasteboardController = pasteboardController
        
        menuItems = []
        visibleServiceCount = 0
        visibleReceivedCount = 0
        
        super.init()
        
        browser.delegate = self
        menu.delegate = self
        service.delegate = self
    }
    
    private func rebuildMenu() {
        menuItems.removeAll(keepingCapacity: true)
        
        visibleServiceCount = browser.services.count
        visibleReceivedCount = pasteboardController.receivedItems.count

        menuItems.append(menuItemForPasteboardPreview())
        
        menuItems.append(NSMenuItem.separator())
        searchStatusMenuItem = NSMenuItem(title: titleForSearchStatusMenuItem())
        menuItems.append(searchStatusMenuItem)
        for service in browser.services {
            let serviceItem = menuItemForService(service: service)
            if pasteboardController.currentItem == nil {
                serviceItem.isEnabled = false
            }
            menuItems.append(serviceItem)
        }
        
        menuItems.append(NSMenuItem.separator())
        receivedStatusMenuItem = NSMenuItem(title: titleForReceivedStatusMenuItem())
        menuItems.append(receivedStatusMenuItem)

        let sortedKeys = pasteboardController.receivedItems.keys.sorted(by: <)
        for key in sortedKeys {
            let pbItem = pasteboardController.receivedItems[key]!
            menuItems.append(menuItemForReceivedPasteboardItem(pbItem, withKey: key))
        }
        
        menuItems.append(NSMenuItem.separator())
        menuItems.append(NSMenuItem(title: "Quit AirCopy", keyEquivalent: "q") { _ in
            NSApplication.shared().terminate(nil)
        })
    }
    
    private func renderMenu() {
        menu.removeAllItems()
        for item in menuItems {
            menu.addItem(item)
        }
    }

    private func menuItemForPasteboardPreview() -> NSMenuItem {
        pasteboardController.updateCurrentItem()
        let item = pasteboardController.currentItem
        let preview = pasteboardController.viewForItem(item: item,
            constrainedToSize: CGSize(width: kDefaultWidth, height: kMaxItemHeight))
        
        let menuItem = NSMenuItem(title: "Clipboard is empty")
        menuItem.view = preview

        if item != nil && preview == nil {
            if let itemType = item?.types.first,
               let dec = UTType(itemType).declaration,
               let desc = dec.typeDescription {
                menuItem.title = "No preview available for " + desc
            }
            else {
                menuItem.title = "No preview available"
            }
        }
        
        return menuItem
    }
    
    private func titleForSearchStatusMenuItem() -> String {
        if browser.isSearching {
            return "Searching..."
        }
        
        return visibleServiceCount > 0 ? "Send clipboard contents to:" : "No nearby computers"
    }
    
    private func titleForReceivedStatusMenuItem() -> String {
        return visibleReceivedCount > 0 ? "Received clipboards:" : "No received clipboards"
    }
    
    private func menuItemForService(service: NetService) -> NSMenuItem {
        let menuItem = NSMenuItem(title: service.name) { [unowned self] _ in
            guard let pasteboardItem = self.pasteboardController.currentItem else {
                return
            }
            let reps = self.pasteboardController.representationsForItem(item: pasteboardItem)
            self.service.sendPasteboardItemsWithRepresentations(reps: [reps], to: service)
        }
        
        menuItem.indentationLevel = 1
        
        return menuItem
    }
    
    private func menuItemForReceivedPasteboardItem(_ pbItem: NSPasteboardItem, withKey key: String) -> NSMenuItem {
        let previewItem = NSMenuItem(title: "<clipboard preview>")
        previewItem.view = pasteboardController.viewForItem(item: pbItem,
            constrainedToSize: CGSize(width: kDefaultWidth, height: kMaxItemHeight))
        
        let applyItem = NSMenuItem(title: "Apply")  { [unowned self] _ in
            self.pasteboardController.makeCurrentReceivedItemWithKey(key: key)
            self.rebuildMenu()
        }
        let deleteItem = NSMenuItem(title: "Delete")  { [unowned self] _ in
            self.pasteboardController.deleteReceiveItemWithKey(key: key)
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
        guard menu.highlightedItem != nil else {
            rebuildMenu()
            renderMenu()
            menu.update()
            return
        }
        
        searchStatusMenuItem.title = titleForSearchStatusMenuItem()
        menu.itemChanged(searchStatusMenuItem)

        receivedStatusMenuItem.title = titleForReceivedStatusMenuItem()
        menu.itemChanged(receivedStatusMenuItem)
    }

    // MARK: - from NSMenuDelegate:
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == self.menu else {
            return
        }

        searchStartDate = Date()
        browser.start()
        rebuildMenu()
        renderMenu()
    }
    
    // MARK: - from AirCopyServiceBrowserDelegate:
    
    func airCopyServiceBrowserDidUpdateServices(_ browser: AirCopyServiceBrowser) {
        let elapsed = Date().timeIntervalSince(searchStartDate!)
        if elapsed > kSearchStatusChangeTreshold {
            updateMenu()
        }
        else {
            let timer = Timer(timeInterval: kSearchStatusChangeTreshold - elapsed,
                target: self,
                selector: #selector(MenuController.updateMenu),
                userInfo: nil,
                repeats: false)
            RunLoop.current.add(timer, forMode: .eventTrackingRunLoopMode)
        }
    }
    
    // MARK: - from AirCopyServiceDelegate:
    
    func airCopyService(_ service: AirCopyService,
        didReceivePasteboardItemsWithRepresentations items: [[Representation]],
        fromNetService netService: NetService) {
        // currently only the first item is used
        guard let reps = items.first else {
            return
        }
        
        pasteboardController.addReceivedItemWithRepresentations(reps, forKey: netService.name)
        
        RunLoop.current.perform(#selector(MenuController.updateMenu),
                                target: self,
                                argument: nil,
                                order: 0,
                                modes: [.eventTrackingRunLoopMode])
    }
    
}
