//
//  AirCopyService.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 27..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation


public protocol AirCopyServiceDelegate: class {
    func airCopyService(service: AirCopyService,
        didReceivePasteboardItemsWithRepresentations: [[(String, NSData)]],
        fromNetService: NSNetService)
}


public class AirCopyService {
    
    static let ServiceType = "_aircopy._tcp."
    
    private let _netService: NSNetService
    private var _inboundTransfers: [NSNetService: (InboundTransfer, [[(String, NSData)]])]
    private var _outboundTransfers: [NSNetService: OutboundTransfer]
    
    private var _netServiceDelegateProxy: NetServiceDelegateProxy!
    private var _inboundTransferDelegateProxy: InboundTransferDelegateProxy!
    private var _outboundTransferDelegateProxy: OutboundTransferDelegateProxy!
    
    public weak var delegate: AirCopyServiceDelegate? = nil

    public static let sharedService = AirCopyService()

    private init() {
        _netService = NSNetService(domain: "", type: AirCopyService.ServiceType, name: "", port: 0)
        _inboundTransfers = [:]
        _outboundTransfers = [:]
        
        _netServiceDelegateProxy = NetServiceDelegateProxy(host: self)
        _inboundTransferDelegateProxy = InboundTransferDelegateProxy(host: self)
        _outboundTransferDelegateProxy = OutboundTransferDelegateProxy(host: self)
    }
    
    public func startAcceptingConnections() {
        _netService.delegate = _netServiceDelegateProxy
        _netService.publishWithOptions(.ListenForConnections)
    }
    
    public func stopAcceptingConnections() {
        _netService.delegate = nil
        _netService.stop()
    }
    
    public func sendPasteboardItemsWithRepresentations(reps: [[(String, NSData)]], toNetService netService: NSNetService) {
        guard _outboundTransfers[netService] == nil else {
            NSLog("simultaneous transfers to the same service are not supported")
            return
        }
        
        var ins: NSInputStream? = nil
        var outs: NSOutputStream? = nil
        guard
            netService.getInputStream(&ins, outputStream: &outs),
            let outputStream = outs where outs != nil
        else {
            return
        }

        outputStream.scheduleInRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        configureSecureTransportForStream(outputStream)

        let transfer = OutboundTransfer(netService: netService, outputStream: outputStream, payload: reps)
        transfer.delegate = _outboundTransferDelegateProxy
        _outboundTransfers[netService] = transfer
        
        transfer.start()
    }
    
    // MARK: - private methods:

    private func configureSecureTransportForStream(stream: NSStream) {
        stream.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
    }
    
    // MARK: - from NSNetServiceDelegate:
    
    private func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        NSLog("incoming connection")
        
        guard _inboundTransfers[sender] == nil else {
            NSLog("simultaneous transfers from the same service are not supported")
            return
        }
        
        inputStream.scheduleInRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        configureSecureTransportForStream(inputStream)
        
        let transfer = InboundTransfer(netService: sender, inputStream: inputStream)
        transfer.delegate = _inboundTransferDelegateProxy
        _inboundTransfers[sender] = (transfer, [])
        
        transfer.start()
    }
    
    // MARK: - from InboundTransferDelegate:
    
    private func inboundTransfer(transfer: InboundTransfer, didProduceItemWithRepresentations reps: [(String, NSData)]) {
        var descriptor = _inboundTransfers[transfer.netService]!
        descriptor.1.append(reps)
        _inboundTransfers[transfer.netService] = descriptor
    }
    
    private func inboundTransferDidEnd(transfer: InboundTransfer) {
        let descriptor = _inboundTransfers[transfer.netService]!
        _inboundTransfers.removeValueForKey(transfer.netService)
        
        self.delegate?.airCopyService(self,
            didReceivePasteboardItemsWithRepresentations: descriptor.1,
            fromNetService: transfer.netService)
    }
    
    // MARK: - from OutboundTransferDelegate:

    private func outboundTransferDidEnd(transfer: OutboundTransfer) {
        _outboundTransfers.removeValueForKey(transfer.netService)
    }
    
}


class NetServiceDelegateProxy: NSObject, NSNetServiceDelegate {
    weak var _host: AirCopyService?
    init(host: AirCopyService) {
        _host = host
    }
    
    func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        _host?.netService(sender, didAcceptConnectionWithInputStream: inputStream, outputStream: outputStream)
    }
}

class InboundTransferDelegateProxy: InboundTransferDelegate {
    weak var _host: AirCopyService?
    init(host: AirCopyService) {
        _host = host
    }
    
    func inboundTransfer(transfer: InboundTransfer, didProduceItemWithRepresentations reps: [(String, NSData)]) {
        _host?.inboundTransfer(transfer, didProduceItemWithRepresentations: reps)
    }
    
    func inboundTransferDidEnd(transfer: InboundTransfer) {
        _host?.inboundTransferDidEnd(transfer)
    }
}

class OutboundTransferDelegateProxy: OutboundTransferDelegate {
    weak var _host: AirCopyService?
    init(host: AirCopyService) {
        _host = host
    }
    
    func outboundTransferDidEnd(transfer: OutboundTransfer) {
        _host?.outboundTransferDidEnd(transfer)
    }
}

