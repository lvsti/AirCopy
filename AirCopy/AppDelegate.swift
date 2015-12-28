//
//  AppDelegate.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 27..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Cocoa

let kDefaultWidth: CGFloat = 250
let kMaxItemHeight: CGFloat = 250

enum PasteboardItemRepresentation {
    case Text(String)
    case Image(NSImage)
}


extension NSMenuItem {
    class func staticItemWithTitle(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.enabled = false
        return item
    }
}

enum IOError: ErrorType {
    case Unknown
}

extension NSOutputStream {
    func writeUInt64(value: UInt64) throws -> Int {
        let ptr = UnsafeMutablePointer<UInt64>.alloc(1)
        defer { ptr.dealloc(1) }
        ptr.initialize(value.bigEndian)
        
        let length = sizeof(UInt64)
        let count = write(UnsafePointer<UInt8>(ptr), maxLength: length)
        if count < length {
            throw IOError.Unknown
        }
        return count
    }
    
    func writeUTF8String(string: String) throws -> Int {
        guard let data = string.dataUsingEncoding(NSUTF8StringEncoding) else {
            throw IOError.Unknown
        }
        return try writeData(data)
    }
    
    func writeData(data: NSData) throws -> Int {
        let count = try writeUInt64(UInt64(data.length))
        let count2 = write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        if count2 < data.length {
            throw IOError.Unknown
        }
        
        return count + count2
    }
}


class ActionTrampoline<T>: NSObject {
    private let _action: T -> Void
    
    init(action: T -> Void) {
        _action = action
        super.init()
    }
    
    @objc
    func action(sender: AnyObject) {
        _action(sender as! T)
    }
}


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSNetServiceBrowserDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    var statusItem: NSStatusItem!
    var browser: NSNetServiceBrowser!
    var currentServices: [NSNetService] = []
    var currentPasteboardItems: [NSPasteboardItem] = []
    var trampoline: ActionTrampoline<NSMenuItem>!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        AirCopyService.sharedService.start()

        trampoline = ActionTrampoline<NSMenuItem> { [weak self] (item: NSMenuItem) in
            NSLog("menu item clicked: %@", item)
            self!.browser.stop()
            
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
            
            itemLoop:
            for pbItem in pbItems {
                NSLog("types: %@", pbItem.types)
                for type in pbItem.types {
                    guard let itemData = pbItem.dataForType(type) else {
                        continue
                    }
                    do {
                        try outputStream.writeUTF8String(type)
                        try outputStream.writeData(itemData)
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
        
        browser = NSNetServiceBrowser()
        browser.delegate = self
        browser.searchForServicesOfType(AirCopyService.ServiceType, inDomain: "")
        
        NSNotificationCenter.defaultCenter().addObserverForName(NSMenuDidBeginTrackingNotification, object: statusMenu, queue: nil) { [weak self] notif in
            guard let this = self else { return }
            this.updateMenuWithServices(this.currentServices)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        AirCopyService.sharedService.stop()
    }
    
    func updatePasteboardItems() {
        let pasteboard = NSPasteboard.generalPasteboard()
        guard let items = pasteboard.pasteboardItems else {
            return
        }
        
        currentPasteboardItems = items
    }
    
    func updateMenuWithServices(services: [NSNetService]) {
        statusMenu.removeAllItems()
        
        if let pasteboardView = currentPasteboardView() {
            let pasteboardItem = NSMenuItem()
            pasteboardItem.view = pasteboardView
            statusMenu.addItem(pasteboardItem)
        }
        else {
            statusMenu.addItem(NSMenuItem.staticItemWithTitle("Clipboard is empty"))
        }
        
        
        statusMenu.addItem(NSMenuItem.separatorItem())
        
        if services.count > 0 {
            statusMenu.addItem(NSMenuItem.staticItemWithTitle("Send clipboard contents to:"))
        }
        else {
            statusMenu.addItem(NSMenuItem.staticItemWithTitle("No nearby devices"))
        }
        
        for service in services {
            let item = NSMenuItem(title: service.name, action: Selector("action:"), keyEquivalent: "")
            item.target = trampoline
            item.representedObject = service
            item.indentationLevel = 1
            statusMenu.addItem(item)
        }
        
        statusMenu.addItem(NSMenuItem.separatorItem())
        
        let item = NSMenuItem(title: "Quit AirCopy", action: Selector("terminate:"), keyEquivalent: "q")
        item.target = NSApplication.sharedApplication()
        statusMenu.addItem(item)
    }
    
    func currentPasteboardView() -> NSView? {
        updatePasteboardItems()
        
        guard
            let item = currentPasteboardItems.first,
            let preferredType = item.types.first
        else {
            return nil
        }
        
        if UTTypeConformsTo(preferredType, kUTTypeImage) {
            guard
                let imageData = item.dataForType(preferredType),
                let image = NSImage(data: imageData)
            else {
                return nil
            }

            let view = NSImageView(frame: NSRect(x: 0, y: 0, width: kDefaultWidth, height: min(image.size.height, kDefaultWidth*image.size.height/image.size.width)))
            view.image = image
            return view
        }

        if UTTypeConformsTo(preferredType, kUTTypeText) {
            guard
                let string = item.stringForType(preferredType)
            else {
                return nil
            }
            
            let view = NSTextField(frame: NSRect(x: 0, y: 0, width: kDefaultWidth, height: kMaxItemHeight))
            view.selectable = false
            view.editable = false
            view.bezeled = false
            view.stringValue = string
            
            var fitSize = view.sizeThatFits(NSSize(width: kDefaultWidth, height: kMaxItemHeight))
            fitSize.width = kDefaultWidth
            fitSize.height = min(fitSize.height, kMaxItemHeight)
            view.frame = NSRect(origin: CGPoint.zero, size: fitSize)

            return view
        }
        
        return nil
    }
    
    // MARK: - NSNetServiceBrowserDelegate:
    
    func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
        NSLog("service found: %@", service)
        if service != localService.netService {
            currentServices.append(service)
        }
        
        if !moreComing {
            updateMenuWithServices(currentServices)
        }
    }

    func netServiceBrowser(browser: NSNetServiceBrowser, didRemoveService service: NSNetService, moreComing: Bool) {
        NSLog("service disappeared: %@", service)
        
        if let index = currentServices.indexOf(service) {
            currentServices.removeAtIndex(index)
        }
        
        if !moreComing {
            updateMenuWithServices(currentServices)
        }
    }
    
}

