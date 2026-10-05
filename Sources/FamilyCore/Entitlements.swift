import Foundation

/// Reads which entitlements an app was signed with, straight from its executable.
///
/// CloudKit does not report a missing iCloud entitlement as an error: creating a
/// `CKContainer` the build is not entitled to stops the app on the spot. So the app
/// has to know before it asks — and the only honest source is the signature itself.
/// This is plain file reading of the app's own binary, nothing private.
///
/// Entitlements live in one of two places. A device build carries them in its code
/// signature, as an XML or DER blob. A simulator build keeps them in a
/// `__TEXT,__entitlements` section. A build made with signing switched off has
/// neither, and that is exactly the build that used to crash.
public enum SignedEntitlements {
    public enum Answer: Equatable, Sendable {
        /// The value appears among the entitlements this binary was signed with.
        case present
        /// The binary was read and its entitlements, if any, do not include it.
        case absent
        /// The binary could not be understood. Callers must treat this as present:
        /// a format this reader does not know is no reason to switch a feature off.
        case unknown
    }

    private static let machMagic64: UInt32 = 0xfeed_facf
    private static let fatMagic: UInt32 = 0xcafe_babe
    private static let fatMagic64: UInt32 = 0xcafe_babf
    private static let loadSegment64: UInt32 = 0x19
    private static let loadCodeSignature: UInt32 = 0x1d
    private static let superBlobMagic: UInt32 = 0xfade_0cc0
    private static let entitlementsXMLMagic: UInt32 = 0xfade_7171
    private static let entitlementsDERMagic: UInt32 = 0xfade_7172

    /// Whether `value` — a container identifier, say — is among the entitlements
    /// signed into this Mach-O executable.
    ///
    /// A universal binary is answered slice by slice. Every architecture is signed
    /// with the same entitlements, so one slice that has them is enough — and one
    /// that cannot be read makes the whole answer unknown, never absent.
    public static func contains(_ value: String, inExecutable binary: Data) -> Answer {
        guard !value.isEmpty else { return .unknown }
        let bytes = [UInt8](binary)
        guard let slices = slices(of: bytes) else { return .unknown }
        let needle = Data(value.utf8)
        var answers: [Answer] = []
        for slice in slices {
            guard let entitlements = entitlementBlobs(in: Array(bytes[slice])) else { answers.append(.unknown); continue }
            answers.append(entitlements.contains { $0.range(of: needle) != nil } ? .present : .absent)
        }
        if answers.contains(.present) { return .present }
        return answers.isEmpty || answers.contains(.unknown) ? .unknown : .absent
    }

    /// Where each architecture's Mach-O sits in the file. A thin binary is one slice;
    /// a universal one lists them in a big-endian header.
    private static func slices(of bytes: [UInt8]) -> [Range<Int>]? {
        guard bytes.count >= 8 else { return nil }
        let magic = readBE(bytes, 0)
        guard magic == fatMagic || magic == fatMagic64 else { return [0..<bytes.count] }
        let count = Int(readBE(bytes, 4))
        let entrySize = magic == fatMagic64 ? 32 : 20
        guard count > 0, 8 + count * entrySize <= bytes.count else { return nil }
        var result: [Range<Int>] = []
        for index in 0..<count {
            let entry = 8 + index * entrySize
            let offset: Int, size: Int
            if magic == fatMagic64 {
                offset = Int(UInt64(readBE(bytes, entry + 8)) << 32 | UInt64(readBE(bytes, entry + 12)))
                size = Int(UInt64(readBE(bytes, entry + 16)) << 32 | UInt64(readBE(bytes, entry + 20)))
            } else {
                offset = Int(readBE(bytes, entry + 8)); size = Int(readBE(bytes, entry + 12))
            }
            guard offset >= 0, size >= 0, offset <= bytes.count - size else { return nil }
            result.append(offset..<(offset + size))
        }
        return result
    }

    /// Every entitlements blob in one thin Mach-O: an empty list means it has none,
    /// nil means it could not be read at all.
    static func entitlementBlobs(in bytes: [UInt8]) -> [Data]? {
        guard bytes.count >= 32, readLE(bytes, 0) == machMagic64 else { return nil }
        let commandCount = Int(readLE(bytes, 16))
        var offset = 32
        var blobs: [Data] = []
        for _ in 0..<commandCount {
            guard offset + 8 <= bytes.count else { return nil }
            let command = readLE(bytes, offset)
            let size = Int(readLE(bytes, offset + 4))
            guard size >= 8, offset + size <= bytes.count else { return nil }
            if command == loadSegment64 {
                guard let found = entitlementSection(bytes, segmentAt: offset, size: size) else { return nil }
                blobs += found
            } else if command == loadCodeSignature {
                guard size >= 16 else { return nil }
                let start = Int(readLE(bytes, offset + 8)), length = Int(readLE(bytes, offset + 12))
                guard start >= 0, length >= 0, start + length <= bytes.count,
                      let found = signatureEntitlements(Array(bytes[start..<(start + length)])) else { return nil }
                blobs += found
            }
            offset += size
        }
        return blobs
    }

    /// The `__entitlements` section of a `__TEXT` segment, where a simulator build
    /// keeps them.
    private static func entitlementSection(_ bytes: [UInt8], segmentAt offset: Int, size: Int) -> [Data]? {
        guard size >= 72, name(bytes, offset + 8) == "__TEXT" else { return [] }
        let sectionCount = Int(readLE(bytes, offset + 64))
        var section = offset + 72
        for _ in 0..<sectionCount {
            guard section + 80 <= offset + size else { return nil }
            if name(bytes, section) == "__entitlements" {
                let length = Int(readLE64(bytes, section + 40))
                let start = Int(readLE(bytes, section + 48))
                guard start >= 0, length >= 0, start + length <= bytes.count else { return nil }
                return [Data(bytes[start..<(start + length)])]
            }
            section += 80
        }
        return []
    }

    /// The entitlement blobs inside a code signature. Its numbers are big-endian,
    /// unlike the rest of the file.
    private static func signatureEntitlements(_ signature: [UInt8]) -> [Data]? {
        guard signature.count >= 12, readBE(signature, 0) == superBlobMagic else { return nil }
        let count = Int(readBE(signature, 8))
        guard 12 + count * 8 <= signature.count else { return nil }
        var blobs: [Data] = []
        for index in 0..<count {
            let blobOffset = Int(readBE(signature, 12 + index * 8 + 4))
            guard blobOffset + 8 <= signature.count else { return nil }
            let magic = readBE(signature, blobOffset)
            guard magic == entitlementsXMLMagic || magic == entitlementsDERMagic else { continue }
            let length = Int(readBE(signature, blobOffset + 4))
            guard length >= 8, blobOffset + length <= signature.count else { return nil }
            blobs.append(Data(signature[(blobOffset + 8)..<(blobOffset + length)]))
        }
        return blobs
    }

    private static func readLE(_ bytes: [UInt8], _ at: Int) -> UInt32 {
        UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2]) << 16 | UInt32(bytes[at + 3]) << 24
    }
    private static func readLE64(_ bytes: [UInt8], _ at: Int) -> UInt64 {
        UInt64(readLE(bytes, at)) | UInt64(readLE(bytes, at + 4)) << 32
    }
    private static func readBE(_ bytes: [UInt8], _ at: Int) -> UInt32 {
        UInt32(bytes[at]) << 24 | UInt32(bytes[at + 1]) << 16 | UInt32(bytes[at + 2]) << 8 | UInt32(bytes[at + 3])
    }
    private static func name(_ bytes: [UInt8], _ at: Int) -> String {
        String(decoding: bytes[at..<(at + 16)].prefix { $0 != 0 }, as: UTF8.self)
    }
}
