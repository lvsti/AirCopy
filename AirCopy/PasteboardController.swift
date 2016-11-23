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
import AirCopyFramework


class PasteboardController {
    
    private var _currentItem: NSPasteboardItem? = nil
    var currentItem: NSPasteboardItem? { return _currentItem }
    
    private var _receivedItems: [String: NSPasteboardItem] = [:]
    var receivedItems: [String: NSPasteboardItem] { return _receivedItems }

    private let _pasteboard: NSPasteboard
    
    init() {
        _pasteboard = NSPasteboard.general()
    }
    
    func updateCurrentItem() {
        _currentItem = _pasteboard.pasteboardItems?.first
    }
    
    func addReceivedItemWithRepresentations(_ reps: [Representation], forKey key: String) {
        let pbItem = NSPasteboardItem()
        
        for rep in reps {
            pbItem.setData(rep.1, forType: rep.0)
        }
        
        _receivedItems[key] = pbItem
    }
    
    func representationsForItem(item: NSPasteboardItem) -> [Representation] {
        var reps: [Representation] = []
        
        for repType in item.types {
            guard let repData = item.data(forType: repType) else {
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
            _receivedItems.removeValue(forKey: key)
        }
        
        updateCurrentItem()
    }
    
    func deleteReceiveItemWithKey(key: String) {
        _receivedItems.removeValue(forKey: key)
    }
    
    func viewForItem(item: NSPasteboardItem?, constrainedToSize maxSize: CGSize) -> NSView? {
        guard let item = item else {
            return nil
        }
        
        return
            urlPreview(item: item, constrainedToSize: maxSize) ??
            imagePreview(item: item, constrainedToSize: maxSize) ??
            textPreview(item: item, constrainedToSize: maxSize)
    }
    
    private func urlPreview(item: NSPasteboardItem, constrainedToSize maxSize: CGSize) -> NSView? {
        guard let index = item.types.index(where: { UTType($0).conforms(to: .url) }) else {
            return nil
        }
        
        var urlType = item.types[index]
        
        if UTType(urlType).conforms(to: .fileURL) {
            if let index2 = item.types.index(where: { UTType($0).conforms(to: .utf8PlainText) }) {
                urlType = item.types[index2]
            }
        }
        
        guard let string = item.string(forType: urlType) else {
            return nil
        }
        
        return textPreview(string: string, constrainedToSize: maxSize)
    }
    
    private func imagePreview(item: NSPasteboardItem, constrainedToSize maxSize: CGSize) -> NSView? {
        guard let index = item.types.index(where: { UTType($0).conforms(to: .image) }) else {
            return nil
        }
        
        let imageType = item.types[index]
        
        guard
            let imageData = item.data(forType: imageType),
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
    
    private func textPreview(item: NSPasteboardItem, constrainedToSize maxSize: CGSize) -> NSView? {
        guard let index = item.types.index(where: { UTType($0).conforms(to: .text) }) else {
            return nil
        }
        
        let textType = item.types[index]
        guard let string = item.string(forType: textType) else {
            return nil
        }
        
        return textPreview(string: string, constrainedToSize: maxSize)
    }
    
    private func textPreview(string: String, constrainedToSize maxSize: CGSize) -> NSView? {
        let view = NSTextField(frame: NSRect.zero)
        view.isSelectable = false
        view.isEditable = false
        view.isBezeled = false
        view.stringValue = string
        
        view.preferredMaxLayoutWidth = maxSize.width
        let fitSize = CGSize(width: maxSize.width,
                             height: min(view.intrinsicContentSize.height, maxSize.height))
        view.frame = NSRect(origin: CGPoint.zero, size: fitSize)
    
        return view
    }
    
}

