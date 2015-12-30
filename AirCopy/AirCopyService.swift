//
//  AirCopyService.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 27..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation


class AirCopyService: NSObject, NSNetServiceDelegate, InboundTransferDelegate {
    
    static let ServiceType = "_aircopy._tcp."
    
    private let _netService: NSNetService
    private var _transfers: [NSNetService: InboundTransfer]
    
    static let sharedService = AirCopyService()
    
    private override init() {
        _netService = NSNetService(domain: "", type: AirCopyService.ServiceType, name: "", port: 0)
        _transfers = [:]
        super.init()
    }
    
    func start() {
        _netService.delegate = self
        _netService.publishWithOptions(.ListenForConnections)
    }
    
    func stop() {
        _netService.delegate = nil
        _netService.stop()
    }
    
    // MARK: - from NSNetServiceDelegate:
    
    func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        NSLog("incoming connection")
        
        guard _transfers[sender] == nil else {
            NSLog("simultaneous transfers from the same service are not supported")
            return
        }
        
        inputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        
        let transfer = InboundTransfer(netService: sender, inputStream: inputStream)
        transfer.delegate = self
        _transfers[sender] = transfer
        
        transfer.start()
    }
    
    // MARK: - from InboundTransferDelegate:
    
    func inboundTransferDidProduceItemWithRepresentations(reps: [(String, NSData)]) {
//        NSLog("reps: %@", reps)
    }
    
    func inboundTransferDidEnd(transfer: InboundTransfer) {
        _transfers.removeValueForKey(transfer.netService)
    }
    
}
