//
//  AirCopyService.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 27..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation


class AirCopyService: NSObject, NSNetServiceDelegate, TransferDelegate {
    
    static let ServiceType = "_aircopy._tcp."
    
    private let netService: NSNetService
    private var transfers: Set<InboundTransfer>
    
    static let sharedService = AirCopyService()
    
    private override init() {
        netService = NSNetService(domain: "", type: AirCopyService.ServiceType, name: "", port: 0)
        transfers = []
        super.init()
    }
    
    func start() {
        netService.delegate = self
        netService.publishWithOptions(.ListenForConnections)
    }
    
    func stop() {
        netService.delegate = nil
        netService.stop()
    }
    
    // MARK: - from NSNetServiceDelegate:
    
    func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        NSLog("incoming connection")
        inputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        let transfer = InboundTransfer(service: sender, inputStream: inputStream)
        transfer.delegate = self
        transfers.insert(transfer)
        
        transfer.start()
    }
    
    // MARK: - from TransferDelegate:
    
    func transferDidProduceItemWithContents(contents: [String : NSData]) {
        NSLog("item: %@", contents)
    }
    
    func transferDidEnd(transfer: InboundTransfer) {
        transfers.remove(transfer)
    }
    
}
