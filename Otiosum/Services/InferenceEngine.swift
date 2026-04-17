import Foundation

struct InferenceEngine {
    func assess(
        block: PlannedBlock,
        now: Date,
        context: InferenceContext
    ) -> InferenceAssessment {
        if block.isCompleted {
            return InferenceAssessment(status: .complete, confidence: 1)
        }

        if block.isProtected {
            return InferenceAssessment(status: .protectedTime, confidence: 1)
        }

        if now >= block.start && now <= block.end {
            return InferenceAssessment(
                status: .likelyInProgress,
                confidence: confidenceBoost(for: context, base: 0.82)
            )
        }

        let lateMinutes = Int(now.timeIntervalSince(block.end) / 60)
        if lateMinutes > 0 && lateMinutes <= 90 {
            let base = max(0.35, 0.75 - (Double(lateMinutes) / 180))
            return InferenceAssessment(
                status: .gentlyLate,
                confidence: confidenceBoost(for: context, base: base)
            )
        }

        if now < block.start {
            return InferenceAssessment(status: .upcoming, confidence: 0.7)
        }

        return InferenceAssessment(status: .waiting, confidence: 0.3)
    }

    func overrunEnd(
        for block: PlannedBlock,
        now: Date,
        context: InferenceContext,
        transitionBufferMinutes: Int
    ) -> Date? {
        let assessment = assess(block: block, now: now, context: context)
        guard assessment.status == .gentlyLate || assessment.status == .likelyInProgress else {
            return nil
        }

        guard assessment.confidence >= 0.55 else {
            return nil
        }

        let roundedNow = roundUpToFiveMinutes(now)
        return max(block.end, roundedNow.adding(minutes: transitionBufferMinutes))
    }

    private func confidenceBoost(for context: InferenceContext, base: Double) -> Double {
        guard context.isSceneActive else { return base }
        guard let lastUserInteraction = context.lastUserInteraction else { return min(1, base + 0.08) }

        let delta = context.now.timeIntervalSince(lastUserInteraction)
        if delta <= 120 {
            return min(1, base + 0.15)
        }

        if delta <= 600 {
            return min(1, base + 0.08)
        }

        return base
    }

    private func roundUpToFiveMinutes(_ date: Date) -> Date {
        let timeInterval = date.timeIntervalSinceReferenceDate
        let fiveMinutes: TimeInterval = 5 * 60
        let rounded = ceil(timeInterval / fiveMinutes) * fiveMinutes
        return Date(timeIntervalSinceReferenceDate: rounded)
    }
}
