//
//  InboundTransfer.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 28..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

protocol InboundTransferDelegate: class {
    func inboundTransfer(transfer: InboundTransfer, didProduceItemWithRepresentations: [(String, NSData)])
    func inboundTransferDidEnd(transfer: InboundTransfer)
}


enum InboundTransferState {
    case AwaitingRepCount, EvaluatingRepCount
    case AwaitingTypeSize, AwaitingType, AwaitingDataSize, AwaitingData, CheckingLoopCondition
    case Trap
}


class InboundTransfer: NSObject, NSStreamDelegate {
    private let _netService: NSNetService
    var netService: NSNetService { return _netService }
    
    private let _inputStream: NSInputStream
    
    private let _incomingData: NSMutableData
    private let _chunk: UnsafeMutablePointer<UInt8>
    private static let ChunkSize = 1024
    
    private var _expectedSize: UInt64 = 0
    private var _repCount: UInt8 = 0
    private var _itemType: String = ""
    private var _itemReps: [(String, NSData)] = []

    private var _stateMachine: StateMachine<InboundTransferState>!
    weak var delegate: InboundTransferDelegate? = nil
    
    init(netService: NSNetService, inputStream: NSInputStream) {
        _netService = netService
        _inputStream = inputStream
        _incomingData = NSMutableData()
        _chunk = UnsafeMutablePointer<UInt8>.alloc(InboundTransfer.ChunkSize)
        
        super.init()
        
        _stateMachine = StateMachine<InboundTransferState>(
            initialState: .AwaitingRepCount,
            transitions: transitionMap()
        )
        
        inputStream.delegate = self
    }
    
    deinit {
        _inputStream.close()
        _chunk.dealloc(InboundTransfer.ChunkSize)
    }
    
    func start() {
        _inputStream.open()
    }
    
    private func transitionMap() -> StateMachine<InboundTransferState>.TransitionMapType {
        var transitions: StateMachine<InboundTransferState>.TransitionMapType = [:]
        
        transitions[.AwaitingRepCount] = [
            Transition(
                nextState: .EvaluatingRepCount,
                condition: { [unowned self] in
                    return self._incomingData.length >= 1
                },
                action: { [unowned self] in
                    self._repCount = UnsafePointer<UInt8>(self._incomingData.bytes).memory
                }
            )
        ]
        
        transitions[.EvaluatingRepCount] = [
            Transition(
                nextState: .Trap,
                condition: { [unowned self] in
                    return self._repCount == 0
                },
                action: {}
            ),
            Transition(
                nextState: .AwaitingTypeSize,
                condition: { [unowned self] in
                    return self._repCount > 0
                },
                action: {}
            )
        ]
        
        transitions[.Trap] = [
            Transition(
                nextState: .Trap,
                condition: { return false },
                action: { [unowned self] () -> Void in
                    self.delegate?.inboundTransferDidEnd(self)
                }
            )
        ]
        
        transitions[.AwaitingTypeSize] = [
            Transition(
                nextState: .AwaitingType,
                condition: { [unowned self] in
                    return self._incomingData.length >= sizeof(UInt64)
                },
                action: { [unowned self] in
                    self._expectedSize = UInt64(bigEndian: UnsafePointer<UInt64>(self._incomingData.bytes).memory)
                    self._incomingData.replaceBytesInRange(NSMakeRange(0, sizeof(UInt64)),
                                                           withBytes: UnsafePointer<Void>(),
                                                           length: 0)
                }
            )
        ]
        
        transitions[.AwaitingType] = [
            Transition(
                nextState: .AwaitingDataSize,
                condition: { [unowned self] in
                    return self._incomingData.length >= Int(self._expectedSize)
                },
                action: { [unowned self] in
                    self._itemType = NSString(bytes: self._incomingData.bytes,
                                              length: Int(self._expectedSize),
                                              encoding: NSUTF8StringEncoding)! as String
                    self._incomingData.replaceBytesInRange(NSMakeRange(0, Int(self._expectedSize)),
                                                           withBytes: UnsafePointer<Void>(),
                                                           length: 0)
                }
            )
        ]
        
        transitions[.AwaitingDataSize] = [
            Transition(
                nextState: .AwaitingData,
                condition: { [unowned self] in
                    return self._incomingData.length >= sizeof(UInt64)
                },
                action: { [unowned self] in
                    self._expectedSize = UInt64(bigEndian: UnsafePointer<UInt64>(self._incomingData.bytes).memory)
                    self._incomingData.replaceBytesInRange(NSMakeRange(0, sizeof(UInt64)),
                                                           withBytes: UnsafePointer<Void>(),
                                                           length: 0)
                }
            )
        ]
        
        transitions[.AwaitingData] = [
            Transition(
                nextState: .CheckingLoopCondition,
                condition: { [unowned self] in
                    return self._incomingData.length >= Int(self._expectedSize)
                },
                action: { [unowned self] in
                    let itemData = self._incomingData.subdataWithRange(NSMakeRange(0, Int(self._expectedSize)))
                    self._itemReps.append((self._itemType, itemData))
                    self._incomingData.replaceBytesInRange(NSMakeRange(0, Int(self._expectedSize)),
                                                           withBytes: UnsafePointer<Void>(),
                                                           length: 0)
                    self._repCount -= 1
                }
            )
        ]
        
        transitions[.CheckingLoopCondition] = [
            Transition(
                nextState: .AwaitingRepCount,
                condition: { [unowned self] in
                    return self._repCount == 0
                },
                action: { [unowned self] () -> Void in
                    self.delegate?.inboundTransfer(self, didProduceItemWithRepresentations: self._itemReps)
                }
            ),
            Transition(
                nextState: .AwaitingTypeSize,
                condition: { [unowned self] in
                    return self._repCount > 0
                },
                action: {}
            )
        ]
        
        return transitions
    }
    
    // from NSStreamDelegate:
 
    func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
        guard eventCode != .EndEncountered else {
            stream.close()
            delegate?.inboundTransferDidEnd(self)
            return
        }

        guard eventCode == .HasBytesAvailable else {
            return
        }

        let count = _inputStream.read(_chunk, maxLength: InboundTransfer.ChunkSize)
        _incomingData.appendBytes(_chunk, length: count)

        _stateMachine.step()
    }

}
