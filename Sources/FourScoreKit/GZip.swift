import Foundation
import zlib

public enum GZipError: Error, LocalizedError {
    case notGzip
    case zlib(Int32, String?)

    public var errorDescription: String? {
        switch self {
        case .notGzip: "Data is not gzip-compressed"
        case .zlib(let code, let msg): "zlib error \(code)\(msg.map { ": \($0)" } ?? "")"
        }
    }
}

/// Minimal gzip encode/decode on top of the system zlib.
enum GZip {
    private static let chunk = 1 << 16

    static func isGzip(_ data: Data) -> Bool {
        data.count >= 2 && data[data.startIndex] == 0x1f && data[data.startIndex + 1] == 0x8b
    }

    static func decompress(_ data: Data) throws -> Data {
        guard isGzip(data) else { throw GZipError.notGzip }
        var stream = z_stream()
        // 16 + MAX_WBITS tells zlib to expect a gzip header/trailer.
        var status = inflateInit2_(&stream, 16 + MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw GZipError.zlib(status, nil) }
        defer { inflateEnd(&stream) }

        var output = Data()
        var buffer = [UInt8](repeating: 0, count: chunk)
        try data.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
            stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(input.count)
            repeat {
                status = buffer.withUnsafeMutableBufferPointer { out in
                    stream.next_out = out.baseAddress
                    stream.avail_out = uInt(out.count)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                guard status == Z_OK || status == Z_STREAM_END else {
                    throw GZipError.zlib(status, stream.msg.map { String(cString: $0) })
                }
                output.append(buffer, count: chunk - Int(stream.avail_out))
                if status == Z_OK && stream.avail_in == 0 && stream.avail_out != 0 {
                    throw GZipError.zlib(Z_BUF_ERROR, "truncated gzip stream")
                }
            } while status != Z_STREAM_END
        }
        return output
    }

    /// Compresses with no embedded filename and a zero timestamp (like `gzip -n`).
    static func compress(_ data: Data, level: Int32 = Z_DEFAULT_COMPRESSION) throws -> Data {
        var stream = z_stream()
        var status = deflateInit2_(&stream, level, Z_DEFLATED, 16 + MAX_WBITS, 8, Z_DEFAULT_STRATEGY,
                                   ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw GZipError.zlib(status, nil) }
        defer { deflateEnd(&stream) }

        var output = Data()
        var buffer = [UInt8](repeating: 0, count: chunk)
        try data.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
            stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(input.count)
            repeat {
                status = buffer.withUnsafeMutableBufferPointer { out in
                    stream.next_out = out.baseAddress
                    stream.avail_out = uInt(out.count)
                    return deflate(&stream, Z_FINISH)
                }
                guard status == Z_OK || status == Z_STREAM_END else {
                    throw GZipError.zlib(status, stream.msg.map { String(cString: $0) })
                }
                output.append(buffer, count: chunk - Int(stream.avail_out))
            } while status != Z_STREAM_END
        }
        return output
    }
}
