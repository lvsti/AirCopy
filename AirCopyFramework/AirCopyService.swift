//
//  AirCopyService.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 27..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

public typealias Representation = (String, Data)


public protocol AirCopyServiceDelegate: class {
    func airCopyService(_ service: AirCopyService,
        didReceivePasteboardItemsWithRepresentations: [[Representation]],
        fromNetService: NetService)
}


public class AirCopyService {
    
    static let serviceType = "_aircopy._tcp."
    
    private let netService: NetService
    private var inboundTransfers: [NetService: (InboundTransfer, [[Representation]])]
    private var outboundTransfers: [NetService: OutboundTransfer]
    
    private var netServiceDelegateProxy: NetServiceDelegateProxy!
    private var inboundTransferDelegateProxy: InboundTransferDelegateProxy!
    private var outboundTransferDelegateProxy: OutboundTransferDelegateProxy!
    
    public private(set) var publishedName: String? = nil
    
    public weak var delegate: AirCopyServiceDelegate? = nil

    public static let sharedService = AirCopyService()

    private init() {
        netService = NetService(domain: "", type: AirCopyService.serviceType, name: "", port: 0)
        inboundTransfers = [:]
        outboundTransfers = [:]
        
        netServiceDelegateProxy = NetServiceDelegateProxy(host: self)
        inboundTransferDelegateProxy = InboundTransferDelegateProxy(host: self)
        outboundTransferDelegateProxy = OutboundTransferDelegateProxy(host: self)
    }
    
    public func startAcceptingConnections() {
        netService.delegate = netServiceDelegateProxy
        netService.publish(options: .listenForConnections)
    }
    
    public func stopAcceptingConnections() {
        publishedName = nil
        netService.delegate = nil
        netService.stop()
    }
    
    public func sendPasteboardItemsWithRepresentations(reps: [[Representation]], to netService: NetService) {
        guard outboundTransfers[netService] == nil else {
            NSLog("simultaneous transfers to the same service are not supported")
            return
        }
        
        var ins: InputStream? = nil
        var outs: OutputStream? = nil
        guard
            netService.getInputStream(&ins, outputStream: &outs),
            let outputStream = outs,
            outs != nil
        else {
            return
        }

        outputStream.schedule(in: .main, forMode: .default)
        configureSecureTransport(for: outputStream)

        let transfer = OutboundTransfer(netService: netService, outputStream: outputStream, payload: reps)
        transfer.delegate = outboundTransferDelegateProxy
        outboundTransfers[netService] = transfer
        
        transfer.start()
    }
    
    // MARK: - private methods:

    private func configureSecureTransport(for stream: Stream) {
        stream.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
    }
    
    // MARK: - from NetServiceDelegate:
    
    fileprivate func netServiceDidPublish(_ sender: NetService) {
        publishedName = sender.name
    }
    
    fileprivate func netService(_ sender: NetService, didAcceptConnectionWithInputStream inputStream: InputStream, outputStream: OutputStream) {
        NSLog("incoming connection")
        
        guard inboundTransfers[sender] == nil else {
            NSLog("simultaneous transfers from the same service are not supported")
            return
        }
        
        inputStream.schedule(in: .main, forMode: .default)
        configureSecureTransport(for: inputStream)
        
        let transfer = InboundTransfer(netService: sender, inputStream: inputStream)
        transfer.delegate = inboundTransferDelegateProxy
        inboundTransfers[sender] = (transfer, [])
        
        transfer.start()
    }
    
    // MARK: - from InboundTransferDelegate:
    
    fileprivate func inboundTransfer(_ transfer: InboundTransfer, didProduceItemWithRepresentations reps: [Representation]) {
        var descriptor = inboundTransfers[transfer.netService]!
        descriptor.1.append(reps)
        inboundTransfers[transfer.netService] = descriptor
    }
    
    fileprivate func inboundTransferDidEnd(_ transfer: InboundTransfer) {
        let descriptor = inboundTransfers[transfer.netService]!
        inboundTransfers.removeValue(forKey: transfer.netService)
        
        delegate?.airCopyService(self,
            didReceivePasteboardItemsWithRepresentations: descriptor.1,
            fromNetService: transfer.netService)
    }
    
    // MARK: - from OutboundTransferDelegate:

    fileprivate func outboundTransferDidEnd(_ transfer: OutboundTransfer) {
        outboundTransfers.removeValue(forKey: transfer.netService)
    }
    
}


class NetServiceDelegateProxy: NSObject, NetServiceDelegate {
    weak var host: AirCopyService?
    init(host: AirCopyService) {
        self.host = host
    }
    
    func netServiceDidPublish(_ sender: NetService) {
        host?.netServiceDidPublish(sender)
    }
    
    func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
        host?.netService(sender, didAcceptConnectionWithInputStream: inputStream, outputStream: outputStream)
    }
}

class InboundTransferDelegateProxy: InboundTransferDelegate {
    weak var host: AirCopyService?
    init(host: AirCopyService) {
        self.host = host
    }
    
    func inboundTransfer(_ transfer: InboundTransfer, didProduceItemWithRepresentations reps: [Representation]) {
        host?.inboundTransfer(transfer, didProduceItemWithRepresentations: reps)
    }
    
    func inboundTransferDidEnd(_ transfer: InboundTransfer) {
        host?.inboundTransferDidEnd(transfer)
    }
}

class OutboundTransferDelegateProxy: OutboundTransferDelegate {
    weak var host: AirCopyService?
    init(host: AirCopyService) {
        self.host = host
    }
    
    func outboundTransferDidEnd(_ transfer: OutboundTransfer) {
        host?.outboundTransferDidEnd(transfer)
    }
}

