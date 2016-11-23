//
//  NSMenuItem+Handler.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 29..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation
import AppKit

class ActionTrampoline<T>: NSObject {
    private let _action: (T) -> Void
    
    init(action: @escaping (T) -> Void) {
        _action = action
        super.init()
    }
    
    @objc
    func action(_ sender: AnyObject) {
        _action(sender as! T)
    }
}

private let NSMenuItemHandlerTrampolineKey = UnsafeMutablePointer<Int8>.allocate(capacity: 1)

extension NSMenuItem {
    typealias Handler = (NSMenuItem) -> Void
    
    convenience init(title: String, keyEquivalent: String = "", handler: Handler? = nil) {
        self.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        setHandler(handler)
    }
    
    func setHandler(_ handler: Handler?) {
        let trampoline: ActionTrampoline<NSMenuItem>? = handler != nil ? ActionTrampoline<NSMenuItem>(action: handler!) : nil
        objc_setAssociatedObject(self, NSMenuItemHandlerTrampolineKey, trampoline, .OBJC_ASSOCIATION_RETAIN)
        self.target = trampoline
        self.action = handler != nil ? #selector(ActionTrampoline<NSMenuItem>.action(_:)) : nil
    }
}
