//
//  ServiceBrowser.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 28..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

protocol ServiceBrowserDelegate: class {
    func serviceBrowserDidUpdateServices(browser: ServiceBrowser)
}

class ServiceBrowser: NSObject, NSNetServiceBrowserDelegate {
    
    private let _browser: NSNetServiceBrowser
    
    private var _pendingServices: [NSNetService] = []
    private var _services: [NSNetService] = []
    var services: [NSNetService] { return _services }
    
    weak var delegate: ServiceBrowserDelegate? = nil

    override init() {
        _browser = NSNetServiceBrowser()
        
        super.init()
    }
    
    func start() {
        _browser.delegate = self
        _browser.stop()
        _pendingServices.removeAll(keepCapacity: true)
        _browser.searchForServicesOfType(AirCopyService.ServiceType, inDomain: "")
    }
    
    func stop() {
        _browser.stop()
    }
    
    // MARK: - NSNetServiceBrowserDelegate:
    
    func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
        NSLog("service found: %@", service)
        guard let hostname = NSHost.currentHost().localizedName where service.name != hostname else {
            return
        }

        _pendingServices.append(service)
        
        if !moreComing {
            _services = _pendingServices
            delegate?.serviceBrowserDidUpdateServices(self)
        }
    }

    func netServiceBrowser(browser: NSNetServiceBrowser, didRemoveService service: NSNetService, moreComing: Bool) {
        NSLog("service disappeared: %@", service)
        
        if let index = _pendingServices.indexOf(service) {
            _pendingServices.removeAtIndex(index)
        }
        
        if !moreComing {
            _services = _pendingServices
            delegate?.serviceBrowserDidUpdateServices(self)
        }
    }
    
}

