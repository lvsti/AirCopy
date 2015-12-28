//
//  InboundTransfer.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 28..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

protocol TransferDelegate: class {
    func transferDidProduceItemWithType(type: String, data: NSData)
    func transferDidEnd(transfer: InboundTransfer)
}


enum InboundTransferState {
    case AwaitingTypeSize, AwaitingType, AwaitingDataSize, AwaitingData
}


class InboundTransfer: NSObject, NSStreamDelegate {
    let service: NSNetService
    let inputStream: NSInputStream
    
    let incomingData: NSMutableData
    let chunk: UnsafeMutablePointer<UInt8>
    static let ChunkSize = 1024
    
    var expectedSize: UInt64 = 0
    var itemType: String = ""

    var stateMachine: StateMachine<InboundTransferState>!
    weak var delegate: TransferDelegate? = nil
    
    init(service: NSNetService, inputStream: NSInputStream) {
        self.service = service
        self.inputStream = inputStream
        incomingData = NSMutableData()
        chunk = UnsafeMutablePointer<UInt8>.alloc(InboundTransfer.ChunkSize)
        
        super.init()

        stateMachine = StateMachine<InboundTransferState>(
            initialState: .AwaitingTypeSize,
            transitions: [
                .AwaitingTypeSize: [
                    (nextState: .AwaitingType,
                    condition: { [unowned self] in
                        return self.incomingData.length >= sizeof(UInt64)
                    },
                    action: { [unowned self] in
                        self.expectedSize = UInt64(bigEndian: UnsafePointer<UInt64>(self.incomingData.bytes).memory)
                        self.incomingData.replaceBytesInRange(NSMakeRange(0, sizeof(UInt64)),
                                                              withBytes: UnsafePointer<Void>(),
                                                              length: 0)
                    })
                ],
                .AwaitingType: [
                    (nextState: .AwaitingDataSize,
                    condition: { [unowned self] in
                        return self.incomingData.length >= Int(self.expectedSize)
                    },
                    action: { [unowned self] in
                        self.itemType = NSString(bytes: self.incomingData.bytes,
                                                 length: Int(self.expectedSize),
                                                 encoding: NSUTF8StringEncoding)! as String
                        self.incomingData.replaceBytesInRange(NSMakeRange(0, Int(self.expectedSize)),
                                                              withBytes: UnsafePointer<Void>(),
                                                              length: 0)
                    })
                ],
                .AwaitingDataSize: [
                    (nextState: .AwaitingData,
                    condition: { [unowned self] in
                        return self.incomingData.length >= sizeof(UInt64)
                    },
                    action: { [unowned self] in
                        self.expectedSize = UInt64(bigEndian: UnsafePointer<UInt64>(self.incomingData.bytes).memory)
                        self.incomingData.replaceBytesInRange(NSMakeRange(0, sizeof(UInt64)),
                                                              withBytes: UnsafePointer<Void>(),
                                                              length: 0)
                    })
                ],
                .AwaitingData: [
                    (nextState: .AwaitingTypeSize,
                    condition: { [unowned self] in
                        return self.incomingData.length >= Int(self.expectedSize)
                    },
                    action: { [unowned self] in
                        let itemData = self.incomingData.subdataWithRange(NSMakeRange(0, Int(self.expectedSize)))
                        self.delegate?.transferDidProduceItemWithType(self.itemType, data: itemData)
                        self.incomingData.replaceBytesInRange(NSMakeRange(0, Int(self.expectedSize)),
                                                              withBytes: UnsafePointer<Void>(),
                                                              length: 0)
                    })
                ]
            ]
        )
        
        inputStream.delegate = self
    }
    
    deinit {
        inputStream.close()
        chunk.dealloc(InboundTransfer.ChunkSize)
    }
    
    func start() {
        inputStream.open()
    }
    
    // from NSStreamDelegate:
 
    func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
        guard eventCode != .EndEncountered else {
            stream.close()
            delegate?.transferDidEnd(self)
            return
        }

        guard eventCode == .HasBytesAvailable else {
            return
        }

        let count = inputStream.read(chunk, maxLength: InboundTransfer.ChunkSize)
        incomingData.appendBytes(chunk, length: count)

        stateMachine.step()
    }

}
