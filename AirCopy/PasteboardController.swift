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

    init() {
        
    }
    
    func update() {
        let pasteboard = NSPasteboard.generalPasteboard()
        _currentItem = pasteboard.pasteboardItems?.first
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
            
            var fitSize = view.sizeThatFits(maxSize)
            fitSize.width = maxSize.width
            fitSize.height = min(fitSize.height, maxSize.height)
            view.frame = NSRect(origin: CGPoint.zero, size: fitSize)
            
            return view
        }

        return nil
    }
    
}

