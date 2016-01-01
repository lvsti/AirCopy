//
//  OutboundTransfer.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 29..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

enum IOError: ErrorType {
    case Unknown
}

extension NSOutputStream {
    func writeUInt8(value: UInt8) throws -> Int {
        let ptr = UnsafeMutablePointer<UInt8>.alloc(1)
        defer { ptr.dealloc(1) }
        ptr.initialize(value)
        
        let count = write(ptr, maxLength: 1)
        if count < 1 {
            throw IOError.Unknown
        }
        return 1
    }
    
    func writeUInt64(value: UInt64) throws -> Int {
        let ptr = UnsafeMutablePointer<UInt64>.alloc(1)
        defer { ptr.dealloc(1) }
        ptr.initialize(value.bigEndian)
        
        let length = sizeof(UInt64)
        let count = write(UnsafePointer<UInt8>(ptr), maxLength: length)
        if count < length {
            throw IOError.Unknown
        }
        return count
    }
    
    func writeUTF8String(string: String) throws -> Int {
        guard let data = string.dataUsingEncoding(NSUTF8StringEncoding) else {
            throw IOError.Unknown
        }
        return try writeData(data)
    }
    
    func writeData(data: NSData) throws -> Int {
        let count = try writeUInt64(UInt64(data.length))
        let count2 = write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        if count2 < data.length {
            throw IOError.Unknown
        }
        
        return count + count2
    }
}


protocol OutboundTransferDelegate: class {
    func outboundTransferDidEnd(transfer: OutboundTransfer)
}

class OutboundTransfer: NSObject, NSStreamDelegate {
    // dependencies
    private let _netService: NSNetService
    var netService: NSNetService { return _netService }
    private let _outputStream: NSOutputStream
    
    private let _payload: [[(String, NSData)]]
    
    // state
    private var _outgoingData: NSData!
    private var _outgoingDataOffset: Int
    weak var delegate: OutboundTransferDelegate? = nil
    
    init(netService: NSNetService, outputStream: NSOutputStream, payload: [[(String, NSData)]]) {
        _netService = netService
        _outputStream = outputStream
        _payload = payload
        
        _outgoingDataOffset = 0
        
        super.init()
        
        _outputStream.delegate = self
    }
    
    func start() {
        let dataStream = NSOutputStream.outputStreamToMemory()
        dataStream.open()
        
        do {
            for pbItemReps in _payload {
                try dataStream.writeUInt8(UInt8(pbItemReps.count))
                for (repType, repData) in pbItemReps {
                    try dataStream.writeUTF8String(repType)
                    try dataStream.writeData(repData)
                }
            }
        }
        catch {
            delegate?.outboundTransferDidEnd(self)
            return
        }
        
        dataStream.close()
        
        guard let rawData = dataStream.propertyForKey(NSStreamDataWrittenToMemoryStreamKey) as? NSData else {
            delegate?.outboundTransferDidEnd(self)
            return
        }
        
        _outgoingData = rawData
        _outgoingDataOffset = 0
        
        if _outputStream.streamStatus == NSStreamStatus.NotOpen {
            _outputStream.open()
        }
    }
    
    // MARK: - from NSStreamDelegate:
    
    func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
        guard eventCode != .EndEncountered && eventCode != .ErrorOccurred else {
            stream.close()
            delegate?.outboundTransferDidEnd(self)
            return
        }
        
        guard eventCode == .HasSpaceAvailable else {
            return
        }
        
        let count = _outputStream.write(UnsafePointer<UInt8>(_outgoingData.bytes), maxLength: _outgoingData.length - _outgoingDataOffset)
        guard count >= 0 else {
            stream.close()
            delegate?.outboundTransferDidEnd(self)
            return
        }
        
        _outgoingDataOffset += count
    }
    
}

