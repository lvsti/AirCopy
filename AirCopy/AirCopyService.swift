//
//  AirCopyService.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 27..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

enum StreamError: ErrorType {
    case Incomplete(read: Int, expected: Int)
}

protocol TransferDelegate: class {
    func transferDidProduceItemWithType(type: String, data: NSData)
    func transferDidEnd(transfer: InboundTransfer)
}


class StateMachine<StateType: Hashable> {
    typealias Transition = (nextState: StateType, condition: () -> Bool, action: () -> Void)
    let transitions: [StateType: [Transition]]
    
    private var _currentState: StateType
    var currentState: StateType { return _currentState }
    
    init(initialState: StateType, transitions: [StateType: [Transition]]) {
        self.transitions = transitions
        _currentState = initialState
    }
    
    func step() {
        loop: while true {
            guard let possibleTransitions = transitions[_currentState] else {
                return
            }
            
            for transition in possibleTransitions {
                if transition.condition() {
                    _currentState = transition.nextState
                    transition.action()
                    continue loop
                }
            }
        }
    }
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


class AirCopyService : NSObject, NSNetServiceDelegate, TransferDelegate {
    
    let netService: NSNetService
    var transfers: Set<InboundTransfer>
    
    override init() {
        netService = NSNetService(domain: "", type: "_aircopy._tcp.", name: "", port: 0)
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
    
    func transferDidProduceItemWithType(type: String, data: NSData) {
        NSLog("item: %@, %@", type, data)
    }
    
    func transferDidEnd(transfer: InboundTransfer) {
        transfers.remove(transfer)
    }
    
}
