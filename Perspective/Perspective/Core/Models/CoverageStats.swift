import Foundation

// Five named buckets collapsed from the 7-point political scale.
// Conforms to Equatable so CoverageSpectrum can animate transitions.
struct FiveBucketCoverage: Equatable {
    let extGauche: Double  // lean 1
    let gauche:    Double  // leans 2 + 3
    let centre:    Double  // lean 4
    let droite:    Double  // leans 5 + 6
    let extDroite: Double  // lean 7
}

struct CoverageStats: Codable, Hashable {
    let storyID: UUID

    let lean1Count: Int
    let lean2Count: Int
    let lean3Count: Int
    let lean4Count: Int
    let lean5Count: Int
    let lean6Count: Int
    let lean7Count: Int
    let totalCount: Int

    let lean1Pct: Double
    let lean2Pct: Double
    let lean3Pct: Double
    let lean4Pct: Double
    let lean5Pct: Double
    let lean6Pct: Double
    let lean7Pct: Double

    init(
        storyID: UUID,
        lean1Count: Int, lean2Count: Int, lean3Count: Int, lean4Count: Int,
        lean5Count: Int, lean6Count: Int, lean7Count: Int, totalCount: Int,
        lean1Pct: Double, lean2Pct: Double, lean3Pct: Double, lean4Pct: Double,
        lean5Pct: Double, lean6Pct: Double, lean7Pct: Double
    ) {
        self.storyID = storyID
        self.lean1Count = lean1Count; self.lean2Count = lean2Count
        self.lean3Count = lean3Count; self.lean4Count = lean4Count
        self.lean5Count = lean5Count; self.lean6Count = lean6Count
        self.lean7Count = lean7Count; self.totalCount = totalCount
        self.lean1Pct = lean1Pct; self.lean2Pct = lean2Pct
        self.lean3Pct = lean3Pct; self.lean4Pct = lean4Pct
        self.lean5Pct = lean5Pct; self.lean6Pct = lean6Pct
        self.lean7Pct = lean7Pct
    }

    enum CodingKeys: String, CodingKey {
        case storyID    = "story_id"
        case lean1Count = "lean_1_count"
        case lean2Count = "lean_2_count"
        case lean3Count = "lean_3_count"
        case lean4Count = "lean_4_count"
        case lean5Count = "lean_5_count"
        case lean6Count = "lean_6_count"
        case lean7Count = "lean_7_count"
        case totalCount = "total_count"
        case lean1Pct   = "lean_1_pct"
        case lean2Pct   = "lean_2_pct"
        case lean3Pct   = "lean_3_pct"
        case lean4Pct   = "lean_4_pct"
        case lean5Pct   = "lean_5_pct"
        case lean6Pct   = "lean_6_pct"
        case lean7Pct   = "lean_7_pct"
    }

    // PostgreSQL returns 0 and 1 as integers in JSON; Swift's Decoder
    // refuses to coerce Int → Double, so we try Double first, then Int.
    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) throws -> Double {
        if let v = try? container.decode(Double.self, forKey: key) { return v }
        return Double(try container.decode(Int.self, forKey: key))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        storyID    = try c.decode(UUID.self, forKey: .storyID)
        lean1Count = try c.decode(Int.self, forKey: .lean1Count)
        lean2Count = try c.decode(Int.self, forKey: .lean2Count)
        lean3Count = try c.decode(Int.self, forKey: .lean3Count)
        lean4Count = try c.decode(Int.self, forKey: .lean4Count)
        lean5Count = try c.decode(Int.self, forKey: .lean5Count)
        lean6Count = try c.decode(Int.self, forKey: .lean6Count)
        lean7Count = try c.decode(Int.self, forKey: .lean7Count)
        totalCount = try c.decode(Int.self, forKey: .totalCount)
        lean1Pct = try Self.decodeDouble(c, .lean1Pct)
        lean2Pct = try Self.decodeDouble(c, .lean2Pct)
        lean3Pct = try Self.decodeDouble(c, .lean3Pct)
        lean4Pct = try Self.decodeDouble(c, .lean4Pct)
        lean5Pct = try Self.decodeDouble(c, .lean5Pct)
        lean6Pct = try Self.decodeDouble(c, .lean6Pct)
        lean7Pct = try Self.decodeDouble(c, .lean7Pct)
    }

    // The 7 percentage values in lean order (1→7), summing to ≈1.0
    var spectrumData: [Double] {
        [lean1Pct, lean2Pct, lean3Pct, lean4Pct, lean5Pct, lean6Pct, lean7Pct]
    }

    // Collapses the 7-point scale into a typed FiveBucketCoverage for CoverageSpectrum.
    // The raw values already sum to 1.0 (same percentages, just regrouped);
    // normalization is applied as a safety guard against floating-point drift.
    var fiveBucketCoverage: FiveBucketCoverage {
        let eg = lean1Pct
        let g  = lean2Pct + lean3Pct
        let c  = lean4Pct
        let d  = lean5Pct + lean6Pct
        let ed = lean7Pct
        let sum = eg + g + c + d + ed
        guard sum > 0 else {
            return FiveBucketCoverage(extGauche: 0, gauche: 0, centre: 0, droite: 0, extDroite: 0)
        }
        return FiveBucketCoverage(
            extGauche: eg / sum,
            gauche:    g  / sum,
            centre:    c  / sum,
            droite:    d  / sum,
            extDroite: ed / sum
        )
    }

    // The lean position (1–7) with the highest article count
    var dominantLean: Int {
        let counts = [lean1Count, lean2Count, lean3Count, lean4Count,
                      lean5Count, lean6Count, lean7Count]
        let maxCount = counts.max() ?? 0
        return (counts.firstIndex(of: maxCount) ?? 3) + 1
    }

    // True when all 5 spectrum buckets have at least one article and total >= 5.
    var coversFullSpectrum: Bool {
        lean1Count > 0
        && (lean2Count + lean3Count) > 0
        && lean4Count > 0
        && (lean5Count + lean6Count) > 0
        && lean7Count > 0
        && totalCount >= 5
    }

    // Dynamically generated one-line narrative for the coverage distribution.
    // Priority: dominance → balance → blind spot → empty string.
    static func aggregate(_ stats: [CoverageStats]) -> CoverageStats? {
        guard !stats.isEmpty else { return nil }
        let l1 = stats.reduce(0) { $0 + $1.lean1Count }
        let l2 = stats.reduce(0) { $0 + $1.lean2Count }
        let l3 = stats.reduce(0) { $0 + $1.lean3Count }
        let l4 = stats.reduce(0) { $0 + $1.lean4Count }
        let l5 = stats.reduce(0) { $0 + $1.lean5Count }
        let l6 = stats.reduce(0) { $0 + $1.lean6Count }
        let l7 = stats.reduce(0) { $0 + $1.lean7Count }
        let total = l1 + l2 + l3 + l4 + l5 + l6 + l7
        guard total > 0 else { return nil }
        let t = Double(total)
        return CoverageStats(
            storyID: UUID(),
            lean1Count: l1, lean2Count: l2, lean3Count: l3, lean4Count: l4,
            lean5Count: l5, lean6Count: l6, lean7Count: l7, totalCount: total,
            lean1Pct: Double(l1) / t, lean2Pct: Double(l2) / t,
            lean3Pct: Double(l3) / t, lean4Pct: Double(l4) / t,
            lean5Pct: Double(l5) / t, lean6Pct: Double(l6) / t,
            lean7Pct: Double(l7) / t
        )
    }

    var coverageNarrative: String {
        let fb = fiveBucketCoverage
        let total = fb.extGauche + fb.gauche + fb.centre + fb.droite + fb.extDroite
        guard total > 0 else { return "" }

        let buckets: [(label: String, value: Double)] = [
            ("l'extrême-gauche", fb.extGauche),
            ("la gauche",        fb.gauche),
            ("le centre",        fb.centre),
            ("la droite",        fb.droite),
            ("l'extrême-droite", fb.extDroite)
        ]

        // 1. One 5-bucket position exceeds 60%
        if let dominant = buckets.first(where: { $0.value > 0.60 }) {
            return "Dominé par \(dominant.label)"
        }

        // 2. No single position exceeds 40% — considered balanced
        if buckets.allSatisfy({ $0.value < 0.40 }) {
            return "Couverture équilibrée"
        }

        return ""
    }
}
