//
//  PasteboardController.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 29..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation
import AppKit

class PasteboardController {
    
    private var _currentItem: NSPasteboardItem? = nil
    var currentItem: NSPasteboardItem? { return _currentItem }
    
    private var _receivedItems: [String: NSPasteboardItem] = [:]
    var receivedItems: [String: NSPasteboardItem] { return _receivedItems }

    private let _pasteboard: NSPasteboard
    
    init() {
        _pasteboard = NSPasteboard.generalPasteboard()
    }
    
    func updateCurrentItem() {
        _currentItem = _pasteboard.pasteboardItems?.first
    }
    
    func addReceivedItemWithRepresentations(reps: [(String, NSData)], forKey key: String) {
        let pbItem = NSPasteboardItem()
        
        for rep in reps {
            pbItem.setData(rep.1, forType: rep.0)
        }
        
        _receivedItems[key] = pbItem
    }
    
    func representationsForItem(item: NSPasteboardItem) -> [(String, NSData)] {
        var reps: [(String, NSData)] = []
        
        for repType in item.types {
            guard let repData = item.dataForType(repType) else {
                NSLog("cannot get data for representation %@", repType)
                continue
            }
            reps.append((repType, repData))
        }
        
        return reps
    }
    
    func makeCurrentReceivedItemWithKey(key: String) {
        guard let item = _receivedItems[key] else {
            return
        }
        
        _pasteboard.clearContents()
        if _pasteboard.writeObjects([item]) {
            _receivedItems.removeValueForKey(key)
        }
        
        updateCurrentItem()
    }
    
    func deleteReceiveItemWithKey(key: String) {
        _receivedItems.removeValueForKey(key)
    }
    
    func viewForItem(item: NSPasteboardItem?, constrainedToSize maxSize: CGSize) -> NSView? {
        guard
            let item = item,
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
            
            let rect = NSRect(x: 0,
                              y: 0,
                              width: maxSize.width,
                              height: min(image.size.height, maxSize.width*image.size.height/image.size.width))
            let view = NSImageView(frame: rect)
            view.image = image
            return view
        }
        
        if UTTypeConformsTo(preferredType, kUTTypeText) {
            guard
                let string = item.stringForType(preferredType)
            else {
                return nil
            }
            
            let view = NSTextField(frame: NSRect.zero)
            view.selectable = false
            view.editable = false
            view.bezeled = false
            view.stringValue = string
            
            view.preferredMaxLayoutWidth = maxSize.width
            var fitSize = view.intrinsicContentSize// view.sizeThatFits(maxSize)
            fitSize.width = maxSize.width
            fitSize.height = min(fitSize.height, maxSize.height)
            view.frame = NSRect(origin: CGPoint.zero, size: fitSize)
            
            return view
        }

        return nil
    }
    
}

