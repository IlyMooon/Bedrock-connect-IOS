import Foundation

public enum VarIntError: Error {
    case unexpectedEOF
    case overflow(String)
}

public struct VarInt {
    /// Encode an unsigned 32-bit integer into LEB128 varuint bytes
    public static func encodeVarUInt32(_ value: UInt32) -> Data {
        var val = value
        var data = Data()
        while val >= 0x80 {
            data.append(UInt8((val & 0x7F) | 0x80))
            val >>= 7
        }
        data.append(UInt8(val & 0x7F))
        return data
    }

    /// Decode a LEB128 unsigned 32-bit integer from Data
    public static func decodeVarUInt32(_ data: Data, offset: inout Int) throws -> UInt32 {
        var val: UInt32 = 0
        var shift: UInt32 = 0
        while shift < 35 {
            guard offset < data.count else {
                throw VarIntError.unexpectedEOF
            }
            let b = data[offset]
            offset += 1
            val |= UInt32(b & 0x7F) << shift
            if (b & 0x80) == 0 {
                return val
            }
            shift += 7
        }
        throw VarIntError.overflow("varuint32 exceeds 35 bits")
    }

    /// Encode a signed 32-bit integer using ZigZag encoding
    public static func encodeVarInt32(_ value: Int32) -> Data {
        let raw = UInt32(bitPattern: (value << 1) ^ (value >> 31))
        return encodeVarUInt32(raw)
    }

    /// Decode a ZigZag-encoded signed 32-bit integer from Data
    public static func decodeVarInt32(_ data: Data, offset: inout Int) throws -> Int32 {
        let raw = try decodeVarUInt32(data, offset: &offset)
        let val = Int32(bitPattern: (raw >> 1) ^ (~(raw & 1) &+ 1))
        return val
    }

    /// Encode an unsigned 64-bit integer into LEB128 varuint bytes
    public static func encodeVarUInt64(_ value: UInt64) -> Data {
        var val = value
        var data = Data()
        while val >= 0x80 {
            data.append(UInt8((val & 0x7F) | 0x80))
            val >>= 7
        }
        data.append(UInt8(val & 0x7F))
        return data
    }

    /// Decode a LEB128 unsigned 64-bit integer from Data
    public static func decodeVarUInt64(_ data: Data, offset: inout Int) throws -> UInt64 {
        var val: UInt64 = 0
        var shift: UInt64 = 0
        while shift < 70 {
            guard offset < data.count else {
                throw VarIntError.unexpectedEOF
            }
            let b = data[offset]
            offset += 1
            val |= UInt64(b & 0x7F) << shift
            if (b & 0x80) == 0 {
                return val
            }
            shift += 7
        }
        throw VarIntError.overflow("varuint64 exceeds 70 bits")
    }

    /// Encode a string prefixed with its UTF-8 byte length as varuint32
    public static func encodeString(_ string: String) -> Data {
        let utf8 = Data(string.utf8)
        var out = encodeVarUInt32(UInt32(utf8.count))
        out.append(utf8)
        return out
    }

    /// Decode a varuint32 length-prefixed UTF-8 string
    public static func decodeString(_ data: Data, offset: inout Int) throws -> String {
        let length = Int(try decodeVarUInt32(data, offset: &offset))
        guard offset + length <= data.count else {
            throw VarIntError.unexpectedEOF
        }
        let strData = data.subdata(in: offset..<(offset + length))
        offset += length
        return String(data: strData, encoding: .utf8) ?? ""
    }
}
