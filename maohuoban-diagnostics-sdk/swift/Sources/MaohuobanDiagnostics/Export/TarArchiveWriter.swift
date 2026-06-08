import Foundation

// writeTarArchive 写入 tar 归档
// 核心职责：
// - 将 Debug Bundle 文件打包成标准 tar 流
// - 维护 tar header、padding 和 checksum 编码规则
func writeTarArchive(to outputURL: URL, files: [(String, URL)]) throws {
    var archive = Data()
    for (name, url) in files {
        let data = try Data(contentsOf: url)
        archive.append(tarHeader(name: name, size: UInt64(data.count)))
        archive.append(data)
        let padding = (512 - (data.count % 512)) % 512
        if padding > 0 {
            archive.append(Data(repeating: 0, count: padding))
        }
    }
    archive.append(Data(repeating: 0, count: 1_024))
    try archive.write(to: outputURL, options: .atomic)
}

private func tarHeader(name: String, size: UInt64) -> Data {
    var header = [UInt8](repeating: 0, count: 512)
    writeString(name, into: &header, offset: 0, length: 100)
    writeOctal(0o644, into: &header, offset: 100, length: 8)
    writeOctal(0, into: &header, offset: 108, length: 8)
    writeOctal(0, into: &header, offset: 116, length: 8)
    writeOctal(size, into: &header, offset: 124, length: 12)
    writeOctal(0, into: &header, offset: 136, length: 12)
    for index in 148..<156 {
        header[index] = UInt8(ascii: " ")
    }
    header[156] = UInt8(ascii: "0")
    writeString("ustar", into: &header, offset: 257, length: 6)
    writeString("00", into: &header, offset: 263, length: 2)
    let checksum = header.reduce(0) { $0 + UInt32($1) }
    writeChecksum(checksum, into: &header)
    return Data(header)
}

private func writeString(_ value: String, into header: inout [UInt8], offset: Int, length: Int) {
    let bytes = Array(value.utf8.prefix(length))
    header.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
}

private func writeOctal(_ value: UInt64, into header: inout [UInt8], offset: Int, length: Int) {
    let text = String(value, radix: 8)
    let padded = String(repeating: "0", count: max(0, length - 1 - text.count)) + text
    let bytes = Array(padded.utf8.prefix(length - 1))
    header.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
}

private func writeChecksum(_ value: UInt32, into header: inout [UInt8]) {
    let text = String(format: "%06o", value) + "\0 "
    let bytes = Array(text.utf8)
    header.replaceSubrange(148..<(148 + bytes.count), with: bytes)
}
