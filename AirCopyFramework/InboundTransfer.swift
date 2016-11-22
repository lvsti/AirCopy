//
//  InboundTransfer.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 28..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

protocol InboundTransferDelegate: class {
    func inboundTransfer(_ transfer: InboundTransfer, didProduceItemWithRepresentations: [Representation])
    func inboundTransferDidEnd(_ transfer: InboundTransfer)
}


enum InboundTransferState {
    case awaitingRepCount, evaluatingRepCount
    case awaitingTypeSize, awaitingType, awaitingDataSize, awaitingData, checkingLoopCondition
    case trap
}


class InboundTransfer: NSObject, StreamDelegate {
    public let netService: NetService
    
    private let inputStream: InputStream
    
    private let incomingData: NSMutableData
    private let chunk: UnsafeMutablePointer<UInt8>
    private static let chunkSize = 1024
    
    private var expectedSize: UInt64 = 0
    private var repCount: UInt8 = 0
    private var itemType: String = ""
    private var itemReps: [Representation] = []

    private var stateMachine: StateMachine<InboundTransferState>!
    weak var delegate: InboundTransferDelegate? = nil
    
    init(netService: NetService, inputStream: InputStream) {
        self.netService = netService
        self.inputStream = inputStream
        incomingData = NSMutableData()
        chunk = UnsafeMutablePointer<UInt8>.allocate(capacity: InboundTransfer.chunkSize)
        
        super.init()
        
        stateMachine = StateMachine<InboundTransferState>(
            initialState: .awaitingRepCount,
            transitions: transitionMap()
        )
        
        inputStream.delegate = self
    }
    
    deinit {
        inputStream.close()
        chunk.deallocate(capacity: InboundTransfer.chunkSize)
    }
    
    func start() {
        if inputStream.streamStatus == .notOpen {
            inputStream.open()
        }
    }
    
    private func transitionMap() -> StateMachine<InboundTransferState>.TransitionMapType {
        var transitions: StateMachine<InboundTransferState>.TransitionMapType = [:]
        
        transitions[.awaitingRepCount] = [
            Transition(
                nextState: .evaluatingRepCount,
                condition: { [unowned self] in
                    return self.incomingData.length >= 1
                },
                action: { [unowned self] in
                    self.repCount = self.incomingData.bytes.assumingMemoryBound(to: UInt8.self).pointee
                    self.incomingData.replaceBytes(in: NSMakeRange(0, 1),
                                                   withBytes: nil,
                                                   length: 0)
                }
            )
        ]
        
        transitions[.evaluatingRepCount] = [
            Transition(
                nextState: .trap,
                condition: { [unowned self] in
                    return self.repCount == 0
                },
                action: {}
            ),
            Transition(
                nextState: .awaitingTypeSize,
                condition: { [unowned self] in
                    return self.repCount > 0
                },
                action: {}
            )
        ]
        
        transitions[.trap] = [
            Transition(
                nextState: .trap,
                condition: { return false },
                action: { [unowned self] in
                    self.delegate?.inboundTransferDidEnd(self)
                }
            )
        ]
        
        transitions[.awaitingTypeSize] = [
            Transition(
                nextState: .awaitingType,
                condition: { [unowned self] in
                    return self.incomingData.length >= MemoryLayout<UInt64>.size
                },
                action: { [unowned self] in
                    self.expectedSize = UInt64(bigEndian: self.incomingData.bytes.assumingMemoryBound(to: UInt64.self).pointee)
                    self.incomingData.replaceBytes(in: NSMakeRange(0, MemoryLayout<UInt64>.size),
                                                   withBytes: nil,
                                                   length: 0)
                }
            )
        ]
        
        transitions[.awaitingType] = [
            Transition(
                nextState: .awaitingDataSize,
                condition: { [unowned self] in
                    return self.incomingData.length >= Int(self.expectedSize)
                },
                action: { [unowned self] in
                    self.itemType = NSString(bytes: self.incomingData.bytes,
                                             length: Int(self.expectedSize),
                                             encoding: String.Encoding.utf8.rawValue)! as String
                    self.incomingData.replaceBytes(in: NSMakeRange(0, Int(self.expectedSize)),
                                                   withBytes: nil,
                                                   length: 0)
                }
            )
        ]
        
        transitions[.awaitingDataSize] = [
            Transition(
                nextState: .awaitingData,
                condition: { [unowned self] in
                    return self.incomingData.length >= MemoryLayout<UInt64>.size
                },
                action: { [unowned self] in
                    self.expectedSize = UInt64(bigEndian: self.incomingData.bytes.assumingMemoryBound(to: UInt64.self).pointee)
                    self.incomingData.replaceBytes(in: NSMakeRange(0, MemoryLayout<UInt64>.size),
                                                   withBytes: nil,
                                                   length: 0)
                }
            )
        ]
        
        transitions[.awaitingData] = [
            Transition(
                nextState: .checkingLoopCondition,
                condition: { [unowned self] in
                    return self.incomingData.length >= Int(self.expectedSize)
                },
                action: { [unowned self] in
                    let itemData = self.incomingData.subdata(with: NSMakeRange(0, Int(self.expectedSize)))
                    self.itemReps.append((self.itemType, itemData))
                    self.incomingData.replaceBytes(in: NSMakeRange(0, Int(self.expectedSize)),
                                                   withBytes: nil,
                                                   length: 0)
                    self.repCount -= 1
                }
            )
        ]
        
        transitions[.checkingLoopCondition] = [
            Transition(
                nextState: .awaitingRepCount,
                condition: { [unowned self] in
                    return self.repCount == 0
                },
                action: { [unowned self] () -> Void in
                    self.delegate?.inboundTransfer(self, didProduceItemWithRepresentations: self.itemReps)
                }
            ),
            Transition(
                nextState: .awaitingTypeSize,
                condition: { [unowned self] in
                    return self.repCount > 0
                },
                action: {}
            )
        ]
        
        return transitions
    }
    
    // from StreamDelegate:
 
    func stream(_ stream: Stream, handle event: Stream.Event) {
        guard event != .endEncountered && event != .errorOccurred else {
            stream.close()
            delegate?.inboundTransferDidEnd(self)
            return
        }

        guard event == .hasBytesAvailable else {
            return
        }

        let count = inputStream.read(chunk, maxLength: InboundTransfer.chunkSize)
        guard count >= 0 else {
            stream.close()
            delegate?.inboundTransferDidEnd(self)
            return
        }
        
        incomingData.append(chunk, length: count)

        stateMachine.step()
    }

}
