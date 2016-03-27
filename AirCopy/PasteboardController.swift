//
//  PasteboardController.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 29..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation
import AppKit
import Cutis



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
        guard let item = item else {
            return nil
        }
        
        return
            urlPreviewForItem(item, constrainedToSize: maxSize) ??
            imagePreviewForItem(item, constrainedToSize: maxSize) ??
            textPreviewForItem(item, constrainedToSize: maxSize)
    }
    
    private func urlPreviewForItem(item: NSPasteboardItem, constrainedToSize maxSize: CGSize) -> NSView? {
        guard let index = item.types.indexOf({ UTType($0).conformsTo(.URL) }) else {
            return nil
        }
        
        var urlType = item.types[index]
        
        if UTType(urlType).conformsTo(.FileURL) {
            if let index2 = item.types.indexOf({ UTType($0).conformsTo(.UTF8PlainText) }) {
                urlType = item.types[index2]
            }
        }
        
        guard let string = item.stringForType(urlType) else {
            return nil
        }
        
        return textPreviewForString(string, constrainedToSize: maxSize)
    }
    
    private func imagePreviewForItem(item: NSPasteboardItem, constrainedToSize maxSize: CGSize) -> NSView? {
        guard let index = item.types.indexOf({ UTType($0).conformsTo(.Image) }) else {
            return nil
        }
        
        let imageType = item.types[index]
        
        guard
            let imageData = item.dataForType(imageType),
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
    
    private func textPreviewForItem(item: NSPasteboardItem, constrainedToSize maxSize: CGSize) -> NSView? {
        guard let index = item.types.indexOf({ UTType($0).conformsTo(.Text) }) else {
            return nil
        }
        
        let textType = item.types[index]
        guard let string = item.stringForType(textType) else {
            return nil
        }
        
        return textPreviewForString(string, constrainedToSize: maxSize)
    }
    
    private func textPreviewForString(string: String, constrainedToSize maxSize: CGSize) -> NSView? {
        let view = NSTextField(frame: NSRect.zero)
        view.selectable = false
        view.editable = false
        view.bezeled = false
        view.stringValue = string
        
        view.preferredMaxLayoutWidth = maxSize.width
        let fitSize = CGSize(width: maxSize.width,
                             height: min(view.intrinsicContentSize.height, maxSize.height))
        view.frame = NSRect(origin: CGPoint.zero, size: fitSize)
    
        return view
    }
    
}

