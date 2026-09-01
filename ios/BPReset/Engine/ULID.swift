import Foundation

/// `itemId` is a native ULID assigned at commit and exists solely for snapshot-safe
/// acknowledgement (guide §7.3). Globally unique, so `acknowledge` can resolve an item in
/// the active queue or any held bucket without knowing which.
enum ULID {
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")  // Crockford base32
    private static let lock = NSLock()
    private static var lastMillis: UInt64 = 0
    private static var lastRandom: [UInt8] = []

    static func generate(now: Date = Date()) -> String {
        let millis = UInt64((now.timeIntervalSince1970 * 1000).rounded(.down))
        lock.lock()
        var random: [UInt8]
        if millis == lastMillis, !lastRandom.isEmpty {
            random = lastRandom
            // Monotonic within the same millisecond: increment the 80-bit entropy.
            var i = random.count - 1
            while i >= 0 {
                if random[i] == 0xFF { random[i] = 0; i -= 1 } else { random[i] &+= 1; break }
            }
        } else {
            random = (0..<10).map { _ in UInt8.random(in: 0...255) }
        }
        lastMillis = millis
        lastRandom = random
        lock.unlock()

        var bits: [UInt8] = []
        bits.reserveCapacity(16)
        for shift in stride(from: 40, through: 0, by: -8) {
            bits.append(UInt8((millis >> UInt64(shift)) & 0xFF))
        }
        bits.append(contentsOf: random)
        return encode(bits)
    }

    /// 16 bytes -> 26 Crockford base32 characters (130 bits of space, top 2 bits zero).
    private static func encode(_ bytes: [UInt8]) -> String {
        var value: [UInt8] = []
        var acc: UInt32 = 0
        var accBits: UInt32 = 0
        for byte in bytes {
            acc = (acc << 8) | UInt32(byte)
            accBits += 8
            while accBits >= 5 {
                accBits -= 5
                value.append(UInt8((acc >> accBits) & 0x1F))
            }
        }
        if accBits > 0 { value.append(UInt8((acc << (5 - accBits)) & 0x1F)) }
        // 128 bits -> 26 symbols, left-padded so the timestamp stays sortable.
        var out = String(value.map { alphabet[Int($0)] })
        while out.count < 26 { out = "0" + out }
        return String(out.suffix(26))
    }
}
