//
//  AirCopyService.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 27..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation


protocol AirCopyServiceDelegate: class {
    func airCopyService(service: AirCopyService,
        didReceivePasteboardItemsWithRepresentations: [[(String, NSData)]],
        fromNetService: NSNetService)
}

class AirCopyService: NSObject, NSNetServiceDelegate, InboundTransferDelegate, OutboundTransferDelegate {
    
    static let ServiceType = "_aircopy._tcp."
    
    private let _netService: NSNetService
    private var _inboundTransfers: [NSNetService: (InboundTransfer, [[(String, NSData)]])]
    private var _outboundTransfers: [NSNetService: OutboundTransfer]
    
    weak var delegate: AirCopyServiceDelegate? = nil
    
    static let sharedService = AirCopyService()
    
    private override init() {
        _netService = NSNetService(domain: "", type: AirCopyService.ServiceType, name: "", port: 0)
        _inboundTransfers = [:]
        _outboundTransfers = [:]
        super.init()
    }
    
    func startAcceptingConnections() {
        _netService.delegate = self
        _netService.publishWithOptions(.ListenForConnections)
    }
    
    func stopAcceptingConnections() {
        _netService.delegate = nil
        _netService.stop()
    }
    
    func sendPasteboardItemsWithRepresentations(reps: [[(String, NSData)]], toNetService netService: NSNetService) {
        guard _outboundTransfers[netService] == nil else {
            NSLog("simultaneous transfers to the same service are not supported")
            return
        }
        
        var os: NSOutputStream? = nil
        guard
            netService.getInputStream(nil, outputStream: &os),
            let outputStream = os where os != nil
        else {
            return
        }

        outputStream.scheduleInRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        configureSecureTransportForStream(outputStream)

        let transfer = OutboundTransfer(netService: netService, outputStream: outputStream, payload: reps)
        transfer.delegate = self
        _outboundTransfers[netService] = transfer
        
        transfer.start()
    }
    
    // MARK: - private methods:

    private func configureSecureTransportForStream(stream: NSStream) {
//        stream.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
        
//        let settings: [String: AnyObject] = [
//            kCFStreamSSLValidatesCertificateChain as String: false,
//            kCFStreamSSLPeerName as String: kCFNull
//        ]
//        
//        if stream is NSInputStream {
//            CFReadStreamSetProperty(stream as! NSInputStream, kCFStreamPropertySSLSettings, settings)
//        }
//        else if stream is NSOutputStream {
//            CFWriteStreamSetProperty(stream as! NSOutputStream, kCFStreamPropertySSLSettings, settings)
//        }
    }
    
    // MARK: - from NSNetServiceDelegate:
    
    func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        NSLog("incoming connection")
        
        guard _inboundTransfers[sender] == nil else {
            NSLog("simultaneous transfers from the same service are not supported")
            return
        }
        
        inputStream.scheduleInRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        configureSecureTransportForStream(inputStream)
        
        let transfer = InboundTransfer(netService: sender, inputStream: inputStream)
        transfer.delegate = self
        _inboundTransfers[sender] = (transfer, [])
        
        transfer.start()
    }
    
    // MARK: - from InboundTransferDelegate:
    
    func inboundTransfer(transfer: InboundTransfer, didProduceItemWithRepresentations reps: [(String, NSData)]) {
        var descriptor = _inboundTransfers[transfer.netService]!
        descriptor.1.append(reps)
        _inboundTransfers[transfer.netService] = descriptor
    }
    
    func inboundTransferDidEnd(transfer: InboundTransfer) {
        let descriptor = _inboundTransfers[transfer.netService]!
        _inboundTransfers.removeValueForKey(transfer.netService)
        
        self.delegate?.airCopyService(self,
            didReceivePasteboardItemsWithRepresentations: descriptor.1,
            fromNetService: transfer.netService)
    }
    
    // MARK: - from OutboundTransferDelegate:
    
    func outboundTransferDidEnd(transfer: OutboundTransfer) {
        _outboundTransfers.removeValueForKey(transfer.netService)
    }
    
}
