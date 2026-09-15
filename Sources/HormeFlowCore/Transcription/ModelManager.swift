import CryptoKit
import Foundation

public enum ModelManager {
    public static let bundledModelName = "ggml-base.en.bin"
    public static let bundledModelSHA256 = "a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002"

    public static func currentModelURL() -> URL? {
        let fileManager = FileManager.default
        let applicationSupport = appSupportDirectory().appendingPathComponent("Models/\(bundledModelName)")
        if fileManager.fileExists(atPath: applicationSupport.path) { return applicationSupport }

        if let resource = Bundle.main.resourceURL?.appendingPathComponent("Models/\(bundledModelName)"),
           fileManager.fileExists(atPath: resource.path) {
            return resource
        }

        let development = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent(".models/\(bundledModelName)")
        return fileManager.fileExists(atPath: development.path) ? development : nil
    }

    public static func importModel(from source: URL) throws -> URL {
        guard source.pathExtension.lowercased() == "bin" else { throw HormeFlowError.modelInvalid }
        let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
        let bytes = attributes[.size] as? NSNumber
        guard bytes?.int64Value ?? 0 > 1_000_000 else { throw HormeFlowError.modelInvalid }

        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }
        let magic = try handle.read(upToCount: 4) ?? Data()
        guard magic == Data([0x6c, 0x6d, 0x67, 0x67]) else { throw HormeFlowError.modelInvalid }

        let directory = appSupportDirectory().appendingPathComponent("Models", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(bundledModelName)
        let temporary = directory.appendingPathComponent(".import-\(UUID().uuidString).bin")
        try FileManager.default.copyItem(at: source, to: temporary)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        return destination
    }

    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func appSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let current = base.appendingPathComponent("Horme Flow", isDirectory: true)
        let legacy = base.appendingPathComponent("VibeFlow", isDirectory: true)
        if !FileManager.default.fileExists(atPath: current.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: current)
        }
        return current
    }
}
