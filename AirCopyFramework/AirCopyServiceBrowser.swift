//
//  ServiceBrowser.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 28..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

public protocol AirCopyServiceBrowserDelegate: class {
    func airCopyServiceBrowserDidUpdateServices(browser: AirCopyServiceBrowser)
}

public class AirCopyServiceBrowser {
    
    private let _browser: NSNetServiceBrowser
    
    private var _pendingServices: [NSNetService] = []
    private var _services: [NSNetService] = []
    public var services: [NSNetService] { return _services }
    
    private var _isSearching: Bool
    public var isSearching: Bool { return _isSearching }
    
    private var _netServiceBrowserDelegateProxy: NetServiceBrowserDelegateProxy!
    
    public weak var delegate: AirCopyServiceBrowserDelegate? = nil

    public init() {
        _browser = NSNetServiceBrowser()
        _isSearching = false

        _netServiceBrowserDelegateProxy = NetServiceBrowserDelegateProxy(host: self)
    }
    
    public func start() {
        _browser.delegate = _netServiceBrowserDelegateProxy
        _browser.stop()

        _pendingServices.removeAll(keepCapacity: true)
        _browser.searchForServicesOfType(AirCopyService.ServiceType, inDomain: "")
    }
    
    public func stop() {
        _browser.stop()
    }
    
    // MARK: - NSNetServiceBrowserDelegate:
    
    private func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
        if let hostname = NSHost.currentHost().localizedName where service.name != hostname {
            _pendingServices.append(service)
        }
    
        if !moreComing {
            _services = _pendingServices
            _isSearching = false
            delegate?.airCopyServiceBrowserDidUpdateServices(self)
        }
    }

    private func netServiceBrowser(browser: NSNetServiceBrowser, didRemoveService service: NSNetService, moreComing: Bool) {
        if let index = _pendingServices.indexOf(service) {
            _pendingServices.removeAtIndex(index)
        }
        
        if !moreComing {
            _services = _pendingServices
            _isSearching = false
            delegate?.airCopyServiceBrowserDidUpdateServices(self)
        }
    }
    
    private func netServiceBrowserWillSearch(browser: NSNetServiceBrowser) {
        _isSearching = true
    }
    
    private func netServiceBrowserDidStopSearch(browser: NSNetServiceBrowser) {
        _isSearching = false
    }
    
}

class NetServiceBrowserDelegateProxy: NSObject, NSNetServiceBrowserDelegate {
    weak var _host: AirCopyServiceBrowser?
    init(host: AirCopyServiceBrowser) {
        _host = host
    }

    func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
        _host?.netServiceBrowser(browser, didFindService: service, moreComing: moreComing)
    }
    
    func netServiceBrowser(browser: NSNetServiceBrowser, didRemoveService service: NSNetService, moreComing: Bool) {
        _host?.netServiceBrowser(browser, didRemoveService: service, moreComing: moreComing)
    }

    func netServiceBrowserWillSearch(browser: NSNetServiceBrowser) {
        _host?.netServiceBrowserWillSearch(browser)
    }
    
    func netServiceBrowserDidStopSearch(browser: NSNetServiceBrowser) {
        _host?.netServiceBrowserDidStopSearch(browser)
    }
}

