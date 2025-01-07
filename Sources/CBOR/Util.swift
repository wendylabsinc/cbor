enum Util {
    /// DJB2 hash function implementation
    static func djb2Hash(_ values: [Int]) -> Int {
        var hash = 5381
        for value in values {
            hash = ((hash << 5) &+ hash) &+ value
        }
        return hash
    }
} 