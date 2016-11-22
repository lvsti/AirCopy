//
//  ServiceBrowser.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 28..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

public protocol AirCopyServiceBrowserDelegate: class {
    func airCopyServiceBrowserDidUpdateServices(_ browser: AirCopyServiceBrowser)
}

public class AirCopyServiceBrowser {
    
    private let browser: NetServiceBrowser
    
    private var pendingServices: [NetService] = []
    public private(set) var services: [NetService] = []
    
    public private(set) var isSearching: Bool
    
    private var netServiceBrowserDelegateProxy: NetServiceBrowserDelegateProxy!
    
    public weak var delegate: AirCopyServiceBrowserDelegate? = nil

    public init() {
        browser = NetServiceBrowser()
        isSearching = false

        netServiceBrowserDelegateProxy = NetServiceBrowserDelegateProxy(host: self)
    }
    
    public func start() {
        browser.delegate = netServiceBrowserDelegateProxy
        browser.stop()

        pendingServices.removeAll(keepingCapacity: true)
        browser.searchForServices(ofType: AirCopyService.serviceType, inDomain: "")
    }
    
    public func stop() {
        browser.stop()
    }
    
    // MARK: - NetServiceBrowserDelegate:
    
    fileprivate func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        if service.name != AirCopyService.sharedService.publishedName {
            pendingServices.append(service)
        }
    
        if !moreComing {
            services = pendingServices
            isSearching = false
            delegate?.airCopyServiceBrowserDidUpdateServices(self)
        }
    }

    fileprivate func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        if let index = pendingServices.index(of: service) {
            pendingServices.remove(at: index)
        }
        
        if !moreComing {
            services = pendingServices
            isSearching = false
            delegate?.airCopyServiceBrowserDidUpdateServices(self)
        }
    }
    
    fileprivate func netServiceBrowserWillSearch(browser: NetServiceBrowser) {
        isSearching = true
    }
    
    fileprivate func netServiceBrowserDidStopSearch(browser: NetServiceBrowser) {
        isSearching = false
    }
    
}

class NetServiceBrowserDelegateProxy: NSObject, NetServiceBrowserDelegate {
    weak var host: AirCopyServiceBrowser?
    init(host: AirCopyServiceBrowser) {
        self.host = host
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        host?.netServiceBrowser(browser, didFind: service, moreComing: moreComing)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        host?.netServiceBrowser(browser, didRemove: service, moreComing: moreComing)
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        host?.netServiceBrowserWillSearch(browser: browser)
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        host?.netServiceBrowserDidStopSearch(browser: browser)
    }
}

