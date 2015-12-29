//
//  OutboundTransfer.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 29..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

extension NSOutputStream {
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


class OutboundTransfer {
    
    private let _outputStream: NSOutputStream
    
    init(outputStream: NSOutputStream) {
        _outputStream = outputStream
    }
    
    func transferItemWithType(type: String, data: NSData) throws {
        try _outputStream.writeUTF8String(type)
        try _outputStream.writeData(data)
    }
    
}

