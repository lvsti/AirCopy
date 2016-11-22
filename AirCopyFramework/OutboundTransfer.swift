//
//  OutboundTransfer.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 29..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

enum IOError: Error {
    case Unknown
}

extension OutputStream {
    @discardableResult
    func writeUInt8(_ value: UInt8) throws -> Int {
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer { ptr.deallocate(capacity: 1) }
        ptr.initialize(to: value)
        
        let count = write(ptr, maxLength: 1)
        if count < 1 {
            throw IOError.Unknown
        }
        return 1
    }
    
    @discardableResult
    func writeUInt64(_ value: UInt64) throws -> Int {
        let ptr = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { ptr.deallocate(capacity: 1) }
        ptr.initialize(to: value.bigEndian)
        
        let length = MemoryLayout<UInt64>.size
        let count = ptr.withMemoryRebound(to: UInt8.self, capacity: length) { ptr in
            return write(ptr, maxLength: length)
        }

        if count < length {
            throw IOError.Unknown
        }
        return count
    }
    
    @discardableResult
    func writeUTF8String(_ string: String) throws -> Int {
        guard let data = string.data(using: String.Encoding.utf8) else {
            throw IOError.Unknown
        }
        return try writeData(data)
    }
    
    @discardableResult
    func writeData(_ data: Data) throws -> Int {
        let count = try writeUInt64(UInt64(data.count))
        let count2 = data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
            return write(ptr, maxLength: data.count)
        }
        
        if count2 < data.count {
            throw IOError.Unknown
        }
        
        return count + count2
    }
}


protocol OutboundTransferDelegate: class {
    func outboundTransferDidEnd(_ transfer: OutboundTransfer)
}

class OutboundTransfer: NSObject, StreamDelegate {
    // dependencies
    public let netService: NetService
    private let outputStream: OutputStream
    
    private let payload: [[Representation]]
    
    // state
    private var outgoingData: NSData!
    private var outgoingDataOffset: Int
    weak var delegate: OutboundTransferDelegate? = nil
    
    init(netService: NetService, outputStream: OutputStream, payload: [[Representation]]) {
        self.netService = netService
        self.outputStream = outputStream
        self.payload = payload
        
        outgoingDataOffset = 0
        
        super.init()
        
        outputStream.delegate = self
    }
    
    func start() {
        let dataStream = OutputStream.toMemory()
        dataStream.open()
        
        do {
            for pbItemReps in payload {
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
        
        guard let rawData = dataStream.property(forKey: .dataWrittenToMemoryStreamKey) as? NSData else {
            delegate?.outboundTransferDidEnd(self)
            return
        }
        
        outgoingData = rawData
        outgoingDataOffset = 0
        
        if outputStream.streamStatus == .notOpen {
            outputStream.open()
        }
    }
    
    // MARK: - from StreamDelegate:
    
    func stream(_ stream: Stream, handle event: Stream.Event) {
        guard event != .endEncountered && event != .errorOccurred else {
            stream.close()
            delegate?.outboundTransferDidEnd(self)
            return
        }
        
        guard event == .hasSpaceAvailable else {
            return
        }
        
        let ptr = outgoingData.bytes.assumingMemoryBound(to: UInt8.self).advanced(by: outgoingDataOffset)
        let count = outputStream.write(ptr, maxLength: outgoingData.length - outgoingDataOffset)
        
        guard count >= 0 else {
            stream.close()
            delegate?.outboundTransferDidEnd(self)
            return
        }
        
        outgoingDataOffset += count
    }
    
}

