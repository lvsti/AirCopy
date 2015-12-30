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

class OutboundTransfer {
    private let _netService: NSNetService
    var netService: NSNetService { return _netService }
    
    private let _payload: [[(String, NSData)]]
    weak var delegate: OutboundTransferDelegate? = nil
    
    init(netService: NSNetService, payload: [[(String, NSData)]]) {
        _netService = netService
        _payload = payload
    }
    
    func start() {
        defer { self.delegate?.outboundTransferDidEnd(self) }
        
        var os: NSOutputStream? = nil
        guard
            _netService.getInputStream(nil, outputStream: &os),
            let outputStream = os where os != nil
        else {
            return
        }
        
        outputStream.open()

        do {
            for pbItemReps in _payload {
                try outputStream.writeUInt8(UInt8(pbItemReps.count))
                for (repType, repData) in pbItemReps {
                    try outputStream.writeUTF8String(repType)
                    try outputStream.writeData(repData)
                }
            }
        }
        catch {
        }

        outputStream.close()
    }
    
}

func == (lhs: OutboundTransfer, rhs: OutboundTransfer) -> Bool {
    return lhs.netService == rhs.netService
}

extension OutboundTransfer: Hashable {
    var hashValue: Int {
        return _netService.hashValue
    }
}

