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
