import SwiftUI
import WatchKit

enum RainVisualTuning {
    static let surfaceColor = Color(red: 0.018, green: 0.035, blue: 0.045)
    static let rippleColor = RainRipplePalette.skyBlue
    static let maximumParticleCount = 4
    static let reducedMotionLifetime: TimeInterval = 0.46
    static let impactPointLifetime: TimeInterval = 0.24
    static let minimumFrameInterval: TimeInterval = 1.0 / 30.0
}

enum RainRipplePalette {
    static let skyBlue = Color(red: 0.52, green: 0.76, blue: 0.96)
    static let deepBlue = Color(red: 0.34, green: 0.66, blue: 1.0)
    static let teal = Color(red: 0.30, green: 0.84, blue: 0.80)
    static let mint = Color(red: 0.42, green: 0.92, blue: 0.64)
    static let moonlight = Color(red: 0.78, green: 0.93, blue: 1.0)

    private static let vividSkyBlue = Color(red: 0.24, green: 0.88, blue: 1.0)
    private static let vividDeepBlue = Color(red: 0.27, green: 0.58, blue: 1.0)
    private static let vividTeal = Color(red: 0.10, green: 1.0, blue: 0.82)
    private static let vividMint = Color(red: 0.30, green: 1.0, blue: 0.54)

    static func color(
        for style: RippleStyle,
        ringIndex: Int = 0,
        isFeatured: Bool = false
    ) -> Color {
        if style == .directionUp {
            return isFeatured ? vividDeepBlue : deepBlue
        }
        if style == .directionDown {
            return isFeatured ? vividTeal : teal
        }
        if style == .success {
            if ringIndex == 0 {
                return isFeatured ? vividSkyBlue : skyBlue
            }
            return isFeatured ? vividMint : mint
        }
        return isFeatured ? vividSkyBlue : skyBlue
    }
}

enum RainRippleSurprise {
    static let radiusScale: CGFloat = 1.45
    static let lifetimeScale = 1.60
    static let opacityScale = 1.35
    static let lineWidthScale: CGFloat = 1.15
    static let glowStrength = 0.38
    static let echoDelay: TimeInterval = 0.15
    static let echoLifetime: TimeInterval = 0.62
    static let reducedMotionEchoLifetime: TimeInterval = 0.42
    static let echoInitialRadius: CGFloat = 1.4
    static let minimumEchoFinalRadius: CGFloat = 5.5
    static let echoLineWidth: CGFloat = 0.85

    private static let echoOccurrenceSalt: UInt64 = 0xD1B54A32D192ED03
    private static let echoDirectionSalt: UInt64 = 0x94D049BB133111EB
    private static let echoDistanceSalt: UInt64 = 0xBF58476D1CE4E5B9

    static func featuredHitIndex(seed: UInt64, hitCount: Int) -> Int? {
        guard hitCount > 1 else { return nil }

        // Mix the pulse seed before choosing an index so the visual choice is
        // random in use but remains stable through SwiftUI redraws.
        return Int(mixed(seed) % UInt64(hitCount))
    }

    static func isFeatured(_ event: HapticVisualEvent, hitsPerPulse: Int) -> Bool {
        guard supportsRepeatedHits(event.hapticType),
              let featuredIndex = featuredHitIndex(
                seed: event.positionSeed,
                hitCount: hitsPerPulse
              ) else {
            return false
        }
        return event.hitIndex == featuredIndex
    }

    static func supportsRepeatedHits(_ hapticType: WKHapticType) -> Bool {
        hapticType == .click
            || hapticType == .directionUp
            || hapticType == .directionDown
    }

    static func echoPosition(seed: UInt64, around position: CGPoint) -> CGPoint? {
        // Roughly one in three featured pulses receives an echo. Separate salts
        // keep occurrence, direction, and distance independent of hit selection.
        guard mixed(seed ^ echoOccurrenceSalt).isMultiple(of: 3) else {
            return nil
        }

        let angle = unit(mixed(seed ^ echoDirectionSalt)) * .pi * 2
        let distance = 0.055 + (unit(mixed(seed ^ echoDistanceSalt)) * 0.03)
        return CGPoint(
            x: min(max(position.x + (cos(angle) * distance), 0.06), 0.94),
            y: min(max(position.y + (sin(angle) * distance), 0.06), 0.94)
        )
    }

    private static func mixed(_ seed: UInt64) -> UInt64 {
        var value = seed &+ 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    private static func unit(_ value: UInt64) -> CGFloat {
        CGFloat(Double(value >> 11) / Double(1 << 53))
    }
}

enum RainVisualIntensity {
    static let range = 0.0...1.0
    static let defaultValue = 0.5
    static let crownStep = 0.05
    static let maximumRippleOpacityMultiplier = 3.5
    static let maximumLineWidthMultiplier = 2.75
    static let maximumGlowStrength = 0.46

    static func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    static func surfaceOpacity(for intensity: Double) -> Double {
        min(clamped(intensity) * 2, 1)
    }

    static func rippleOpacityMultiplier(for intensity: Double) -> Double {
        let intensity = clamped(intensity)
        guard intensity > defaultValue else {
            return intensity / defaultValue
        }

        let upperRangeProgress = (intensity - defaultValue) / (1 - defaultValue)
        return 1 + (
            upperRangeProgress * (maximumRippleOpacityMultiplier - 1)
        )
    }

    static func lineWidthMultiplier(for intensity: Double) -> Double {
        let intensity = clamped(intensity)
        guard intensity > defaultValue else { return 1 }

        let upperRangeProgress = (intensity - defaultValue) / (1 - defaultValue)
        return 1 + (
            upperRangeProgress * (maximumLineWidthMultiplier - 1)
        )
    }

    static func glowStrength(for intensity: Double) -> Double {
        let intensity = clamped(intensity)
        guard intensity > defaultValue else { return 0 }

        let upperRangeProgress = (intensity - defaultValue) / (1 - defaultValue)
        return upperRangeProgress * maximumGlowStrength
    }
}

struct RippleStyle: Equatable {
    let perceivedStrength: Int
    let ringCount: Int
    let initialRadius: CGFloat
    let finalRadius: CGFloat
    let lifetime: TimeInterval
    let peakOpacity: Double
    let secondaryRingDelay: TimeInterval
    let lineWidth: CGFloat
    let impactPointRadius: CGFloat
    let verticalDrift: CGFloat

    static let click = RippleStyle(
        perceivedStrength: 1,
        ringCount: 1,
        initialRadius: 3,
        finalRadius: 16,
        lifetime: 0.88,
        peakOpacity: 0.22,
        secondaryRingDelay: 0,
        lineWidth: 0.9,
        impactPointRadius: 0.85,
        verticalDrift: 0
    )

    static let transition = RippleStyle(
        perceivedStrength: 2,
        ringCount: 1,
        initialRadius: 3,
        finalRadius: 21,
        lifetime: 0.98,
        peakOpacity: 0.24,
        secondaryRingDelay: 0,
        lineWidth: 1.0,
        impactPointRadius: 1.0,
        verticalDrift: 0
    )

    static let directionDown = RippleStyle(
        perceivedStrength: 3,
        ringCount: 1,
        initialRadius: 3,
        finalRadius: 27,
        lifetime: 1.08,
        peakOpacity: 0.27,
        secondaryRingDelay: 0,
        lineWidth: 1.08,
        impactPointRadius: 1.25,
        verticalDrift: 0
    )

    static let directionUp = RippleStyle(
        perceivedStrength: 4,
        ringCount: 1,
        initialRadius: 3,
        finalRadius: 34,
        lifetime: 1.20,
        peakOpacity: 0.29,
        secondaryRingDelay: 0,
        lineWidth: 1.16,
        impactPointRadius: 1.4,
        verticalDrift: -2.5
    )

    static let success = RippleStyle(
        perceivedStrength: 5,
        ringCount: 2,
        initialRadius: 3,
        finalRadius: 41,
        lifetime: 1.34,
        peakOpacity: 0.32,
        secondaryRingDelay: 0.13,
        lineWidth: 1.24,
        impactPointRadius: 1.6,
        verticalDrift: 0
    )

    static func style(for hapticType: WKHapticType) -> RippleStyle {
        if hapticType == .start || hapticType == .stop { return .transition }
        if hapticType == .directionDown { return .directionDown }
        if hapticType == .directionUp { return .directionUp }
        if hapticType == .success { return .success }
        return .click
    }
}

enum RainSpatialMotif: CaseIterable, Equatable {
    case organic
    case arc
    case diagonal
    case constellation

    private static let selectionSalt: UInt64 = 0xA0761D6478BD642F

    static func selection(seed: UInt64, hitCount: Int) -> RainSpatialMotif {
        guard hitCount >= 4 else { return .organic }

        // Keep most pulses organic. The remaining three eighths are divided
        // evenly among motifs, with the seed making the choice stable per pulse.
        switch mixed(seed ^ selectionSalt) % 8 {
        case 0: return .arc
        case 1: return .diagonal
        case 2: return .constellation
        default: return .organic
        }
    }

    private static func mixed(_ seed: UInt64) -> UInt64 {
        var value = seed &+ 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

struct RainPositionGenerator {
    static func normalizedPosition(
        seed: UInt64,
        hitIndex: Int,
        hitCount: Int = 1,
        motif: RainSpatialMotif = .organic
    ) -> CGPoint {
        switch motif {
        case .organic:
            return organicPosition(seed: seed, hitIndex: hitIndex)
        case .arc:
            return arcPosition(seed: seed, hitIndex: hitIndex, hitCount: hitCount)
        case .diagonal:
            return diagonalPosition(seed: seed, hitIndex: hitIndex, hitCount: hitCount)
        case .constellation:
            return constellationPosition(seed: seed, hitIndex: hitIndex)
        }
    }

    private static func organicPosition(seed: UInt64, hitIndex: Int) -> CGPoint {
        var generator = SplitMix64(state: seed)
        let edgeValue = generator.next()
        let baseX = unit(generator.next())
        let baseY = unit(generator.next())

        var x = 0.14 + (baseX * 0.72)
        var y = 0.16 + (baseY * 0.68)

        if edgeValue.isMultiple(of: 7) {
            switch (edgeValue >> 8) % 4 {
            case 0: x = 0.05
            case 1: x = 0.95
            case 2: y = 0.06
            default: y = 0.94
            }
        }

        if hitIndex > 0 {
            var clusterGenerator = SplitMix64(
                state: seed &+ UInt64(truncatingIfNeeded: hitIndex) &* 0x9E3779B97F4A7C15
            )
            let angle = unit(clusterGenerator.next()) * .pi * 2
            let distance = 0.035 + unit(clusterGenerator.next()) * 0.075
            x += cos(angle) * distance
            y += sin(angle) * distance
        }

        if hypot(x - 0.5, y - 0.5) < 0.08 {
            x += x < 0.5 ? -0.12 : 0.12
            y += y < 0.5 ? 0.07 : -0.07
        }

        return CGPoint(x: min(max(x, 0.03), 0.97), y: min(max(y, 0.03), 0.97))
    }

    private static func arcPosition(
        seed: UInt64,
        hitIndex: Int,
        hitCount: Int
    ) -> CGPoint {
        var generator = SplitMix64(state: seed ^ 0xE7037ED1A0B428DB)
        let rotation = unit(generator.next()) * .pi * 2
        let direction: CGFloat = generator.next().isMultiple(of: 2) ? 1 : -1
        let centerX = 0.5 + ((unit(generator.next()) - 0.5) * 0.08)
        let centerY = 0.5 + ((unit(generator.next()) - 0.5) * 0.08)
        let progress = normalizedProgress(hitIndex: hitIndex, hitCount: hitCount)
        let angle = rotation + (direction * ((progress - 0.5) * 1.75))

        return clampedPosition(CGPoint(
            x: centerX + (cos(angle) * 0.29),
            y: centerY + (sin(angle) * 0.24)
        ))
    }

    private static func diagonalPosition(
        seed: UInt64,
        hitIndex: Int,
        hitCount: Int
    ) -> CGPoint {
        var generator = SplitMix64(state: seed ^ 0x8EBC6AF09C88C6E3)
        let rises = generator.next().isMultiple(of: 2)
        let reverses = generator.next().isMultiple(of: 2)
        let translationX = (unit(generator.next()) - 0.5) * 0.06
        let translationY = (unit(generator.next()) - 0.5) * 0.06
        let rawProgress = normalizedProgress(hitIndex: hitIndex, hitCount: hitCount)
        let progress = reverses ? 1 - rawProgress : rawProgress
        var pointGenerator = SplitMix64(
            state: seed &+ UInt64(truncatingIfNeeded: hitIndex) &* 0xD1342543DE82EF95
        )
        let softness = (unit(pointGenerator.next()) - 0.5) * 0.026
        let x = 0.17 + (progress * 0.66) + translationX + softness
        let baseY = rises ? 0.83 - (progress * 0.66) : 0.17 + (progress * 0.66)
        let y = baseY + translationY + (rises ? softness : -softness)

        return clampedPosition(CGPoint(x: x, y: y))
    }

    private static func constellationPosition(seed: UInt64, hitIndex: Int) -> CGPoint {
        let points = [
            CGPoint(x: -0.32, y: -0.08),
            CGPoint(x: -0.19, y: -0.29),
            CGPoint(x: 0.02, y: -0.18),
            CGPoint(x: 0.16, y: -0.33),
            CGPoint(x: 0.31, y: -0.12),
            CGPoint(x: 0.18, y: 0.04),
            CGPoint(x: 0.34, y: 0.20),
            CGPoint(x: 0.08, y: 0.17),
            CGPoint(x: -0.03, y: 0.34),
            CGPoint(x: -0.18, y: 0.20),
            CGPoint(x: -0.34, y: 0.31),
            CGPoint(x: -0.28, y: 0.07)
        ]
        var generator = SplitMix64(state: seed ^ 0x589965CC75374CC3)
        let rotation = unit(generator.next()) * .pi * 2
        let scale = 0.78 + (unit(generator.next()) * 0.10)
        let centerX = 0.5 + ((unit(generator.next()) - 0.5) * 0.06)
        let centerY = 0.5 + ((unit(generator.next()) - 0.5) * 0.06)
        let offset = Int(generator.next() % UInt64(points.count))
        let pointIndex = (offset + (max(0, hitIndex) * 5)) % points.count
        let point = points[pointIndex]
        let rotatedX = (point.x * cos(rotation)) - (point.y * sin(rotation))
        let rotatedY = (point.x * sin(rotation)) + (point.y * cos(rotation))

        return clampedPosition(CGPoint(
            x: centerX + (rotatedX * scale),
            y: centerY + (rotatedY * scale)
        ))
    }

    private static func normalizedProgress(hitIndex: Int, hitCount: Int) -> CGFloat {
        guard hitCount > 1 else { return 0.5 }
        return CGFloat(min(max(hitIndex, 0), hitCount - 1)) / CGFloat(hitCount - 1)
    }

    private static func clampedPosition(_ position: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(position.x, 0.08), 0.92),
            y: min(max(position.y, 0.08), 0.92)
        )
    }

    private static func unit(_ value: UInt64) -> CGFloat {
        CGFloat(Double(value >> 11) / Double(1 << 53))
    }

    private struct SplitMix64 {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
    }
}

struct RainRingGeometry: Equatable {
    let particleID: UUID
    let center: CGPoint
    let radius: CGFloat
    let opacity: Double
}

struct RainOverlapGlint: Equatable {
    let position: CGPoint
    let strength: Double
    let sourceOpacity: Double
}

enum RainOverlapGlintGeometry {
    static let maximumGlintCount = 4
    static let maximumOverlapFraction: CGFloat = 0.55
    static let minimumGlintSeparation: CGFloat = 4

    static func glints(for rings: [RainRingGeometry]) -> [RainOverlapGlint] {
        guard rings.count > 1 else { return [] }

        var candidates: [RainOverlapGlint] = []
        for firstIndex in rings.indices {
            for secondIndex in rings.index(after: firstIndex)..<rings.endIndex {
                let first = rings[firstIndex]
                let second = rings[secondIndex]
                guard first.particleID != second.particleID else { continue }
                candidates.append(contentsOf: intersections(between: first, and: second))
            }
        }

        candidates.sort {
            ($0.strength * $0.sourceOpacity) > ($1.strength * $1.sourceOpacity)
        }

        var selected: [RainOverlapGlint] = []
        for candidate in candidates {
            let isTooClose = selected.contains {
                hypot(
                    candidate.position.x - $0.position.x,
                    candidate.position.y - $0.position.y
                ) < minimumGlintSeparation
            }
            guard !isTooClose else { continue }
            selected.append(candidate)
            if selected.count == maximumGlintCount { break }
        }
        return selected
    }

    private static func intersections(
        between first: RainRingGeometry,
        and second: RainRingGeometry
    ) -> [RainOverlapGlint] {
        guard first.radius > 0, second.radius > 0,
              first.opacity > 0, second.opacity > 0 else {
            return []
        }

        let deltaX = second.center.x - first.center.x
        let deltaY = second.center.y - first.center.y
        let centerDistance = hypot(deltaX, deltaY)
        let radiusSum = first.radius + second.radius
        let radiusDifference = abs(first.radius - second.radius)
        guard centerDistance > 0.001,
              centerDistance < radiusSum,
              centerDistance > radiusDifference else {
            return []
        }

        // Restrict the highlight to the early part of a collision so it reads
        // as a passing reflection instead of a persistent marker.
        let overlapFraction = (radiusSum - centerDistance)
            / min(first.radius, second.radius)
        guard overlapFraction > 0,
              overlapFraction < maximumOverlapFraction else {
            return []
        }

        let distanceToChord = (
            (first.radius * first.radius)
                - (second.radius * second.radius)
                + (centerDistance * centerDistance)
        ) / (2 * centerDistance)
        let halfChordSquared = (first.radius * first.radius)
            - (distanceToChord * distanceToChord)
        guard halfChordSquared > 0.25 else { return [] }

        let halfChord = sqrt(halfChordSquared)
        let chordCenter = CGPoint(
            x: first.center.x + (distanceToChord * deltaX / centerDistance),
            y: first.center.y + (distanceToChord * deltaY / centerDistance)
        )
        let offsetX = -deltaY * halfChord / centerDistance
        let offsetY = deltaX * halfChord / centerDistance
        let strength = sin(
            .pi * Double(overlapFraction / maximumOverlapFraction)
        )
        let sourceOpacity = min(first.opacity, second.opacity)

        return [
            RainOverlapGlint(
                position: CGPoint(
                    x: chordCenter.x + offsetX,
                    y: chordCenter.y + offsetY
                ),
                strength: strength,
                sourceOpacity: sourceOpacity
            ),
            RainOverlapGlint(
                position: CGPoint(
                    x: chordCenter.x - offsetX,
                    y: chordCenter.y - offsetY
                ),
                strength: strength,
                sourceOpacity: sourceOpacity
            )
        ]
    }
}

struct RainParticle: Identifiable, Equatable {
    let id: UUID
    let position: CGPoint
    let style: RippleStyle
    let startedAt: Date
    let usesReducedMotion: Bool
    let isFeatured: Bool
    let echoPosition: CGPoint?

    var lifetimeScale: Double {
        isFeatured ? RainRippleSurprise.lifetimeScale : 1
    }

    var radiusScale: CGFloat {
        isFeatured ? RainRippleSurprise.radiusScale : 1
    }

    var opacityScale: Double {
        isFeatured ? RainRippleSurprise.opacityScale : 1
    }

    var lineWidthScale: CGFloat {
        isFeatured ? RainRippleSurprise.lineWidthScale : 1
    }

    var echoFinalRadius: CGFloat {
        max(RainRippleSurprise.minimumEchoFinalRadius, style.finalRadius * 0.3)
    }

    var animationLifetime: TimeInterval {
        style.lifetime * lifetimeScale
    }

    var totalLifetime: TimeInterval {
        let primaryLifetime = usesReducedMotion
            ? RainVisualTuning.reducedMotionLifetime * lifetimeScale
            : animationLifetime
                + (style.secondaryRingDelay * Double(max(0, style.ringCount - 1)))
        guard echoPosition != nil else { return primaryLifetime }
        let echoLifetime = usesReducedMotion
            ? RainRippleSurprise.reducedMotionEchoLifetime
            : RainRippleSurprise.echoLifetime
        return max(primaryLifetime, RainRippleSurprise.echoDelay + echoLifetime)
    }
}

@MainActor
final class RainParticleStore: ObservableObject {
    @Published private(set) var particles: [RainParticle] = []
    @Published private(set) var latestParticle: RainParticle?

    private var seenEventIDs: Set<UUID> = []
    private var seenEventOrder: [UUID] = []
    private var removalTasks: [UUID: Task<Void, Never>] = [:]
    private let maximumParticleCount: Int

    init(maximumParticleCount: Int = RainVisualTuning.maximumParticleCount) {
        self.maximumParticleCount = max(1, maximumParticleCount)
    }

    func consume(
        _ events: [HapticVisualEvent],
        visualStyle: ActiveVisualStyle,
        reduceMotion: Bool,
        hitsPerPulse: Int = 1,
        now: Date = Date()
    ) {
        for event in events where !seenEventIDs.contains(event.id) {
            markSeen(event.id)
            guard visualStyle == .stillRain else { continue }

            let effectiveHitCount = RainRippleSurprise.supportsRepeatedHits(
                event.hapticType
            ) ? hitsPerPulse : 1
            let motif = RainSpatialMotif.selection(
                seed: event.positionSeed,
                hitCount: effectiveHitCount
            )
            var position = RainPositionGenerator.normalizedPosition(
                seed: event.positionSeed,
                hitIndex: event.hitIndex,
                hitCount: effectiveHitCount,
                motif: motif
            )
            if motif == .organic,
               let previous = particles.last?.position,
               hypot(position.x - previous.x, position.y - previous.y) < 0.13 {
                position.x = position.x < 0.62 ? position.x + 0.27 : position.x - 0.27
                position.y = position.y < 0.58 ? position.y + 0.18 : position.y - 0.18
            }

            let isFeatured = RainRippleSurprise.isFeatured(
                event,
                hitsPerPulse: hitsPerPulse
            )
            let particle = RainParticle(
                id: event.id,
                position: position,
                style: RippleStyle.style(for: event.hapticType),
                startedAt: event.occurredAt,
                usesReducedMotion: reduceMotion,
                isFeatured: isFeatured,
                echoPosition: isFeatured
                    ? RainRippleSurprise.echoPosition(
                        seed: event.positionSeed,
                        around: position
                    )
                    : nil
            )
            latestParticle = particle
            guard now.timeIntervalSince(particle.startedAt) < particle.totalLifetime else { continue }
            append(particle, now: now)
        }
    }

    func clearParticles() {
        removalTasks.values.forEach { $0.cancel() }
        removalTasks.removeAll()
        particles.removeAll()
    }

    func reset() {
        clearParticles()
        latestParticle = nil
        seenEventIDs.removeAll()
        seenEventOrder.removeAll()
    }

    private func append(_ particle: RainParticle, now: Date) {
        if particles.count >= maximumParticleCount {
            // Keep a featured ripple around long enough for its slower fade to
            // be visible, preferentially retiring an ordinary ripple first.
            let removalIndex = particles.firstIndex { !$0.isFeatured } ?? 0
            let removed = particles.remove(at: removalIndex)
            removalTasks[removed.id]?.cancel()
            removalTasks[removed.id] = nil
        }

        particles.append(particle)
        let remainingLifetime = max(
            0,
            particle.totalLifetime - now.timeIntervalSince(particle.startedAt)
        )
        removalTasks[particle.id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remainingLifetime))
            guard !Task.isCancelled else { return }
            self?.removeParticle(id: particle.id)
        }
    }

    private func removeParticle(id: UUID) {
        particles.removeAll { $0.id == id }
        removalTasks[id] = nil
    }

    private func markSeen(_ id: UUID) {
        seenEventIDs.insert(id)
        seenEventOrder.append(id)
        if seenEventOrder.count > 64 {
            let expired = seenEventOrder.removeFirst()
            seenEventIDs.remove(expired)
        }
    }
}

struct RainSurfaceView: View {
    let events: [HapticVisualEvent]
    let isSessionActive: Bool
    let intensity: Double
    let hitsPerPulse: Int

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var store = RainParticleStore()

    var body: some View {
        ZStack {
            Color.black
            RainVisualTuning.surfaceColor
                .opacity(RainVisualIntensity.surfaceOpacity(for: intensity))

            // Always On throttles subsecond animation, so hold the newest ripple
            // as a static, low-power image until the next visual event arrives.
            if isLuminanceReduced, let latestParticle = store.latestParticle {
                Canvas { context, size in
                    drawAlwaysOnParticle(latestParticle, in: size, context: &context)
                }
                .allowsHitTesting(false)
            } else if !store.particles.isEmpty {
                TimelineView(.animation(
                    minimumInterval: RainVisualTuning.minimumFrameInterval,
                    paused: false
                )) { timeline in
                    Canvas { context, size in
                        drawParticles(store.particles, at: timeline.date, in: size, context: &context)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            store.reset()
            consumeEvents()
        }
        .onChange(of: events) { _, _ in
            consumeEvents()
        }
        .onChange(of: reduceMotion) { _, _ in
            store.reset()
            consumeEvents()
        }
        .onChange(of: isSessionActive) { _, isActive in
            if !isActive {
                store.reset()
            }
        }
        .accessibilityHidden(true)
    }

    private func consumeEvents() {
        store.consume(
            events,
            visualStyle: .stillRain,
            reduceMotion: reduceMotion,
            hitsPerPulse: hitsPerPulse
        )
    }

    private func drawParticles(
        _ particles: [RainParticle],
        at date: Date,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        for particle in particles {
            let elapsed = date.timeIntervalSince(particle.startedAt)
            guard elapsed >= 0, elapsed <= particle.totalLifetime else { continue }

            let center = CGPoint(
                x: particle.position.x * size.width,
                y: particle.position.y * size.height
            )

            if particle.usesReducedMotion {
                drawReducedMotionParticle(particle, elapsed: elapsed, center: center, context: &context)
            } else {
                drawAnimatedParticle(particle, elapsed: elapsed, center: center, context: &context)
            }

            if let echoPosition = particle.echoPosition {
                drawEcho(
                    for: particle,
                    elapsed: elapsed,
                    center: CGPoint(
                        x: echoPosition.x * size.width,
                        y: echoPosition.y * size.height
                    ),
                    context: &context
                )
            }
        }

        drawOverlapGlints(
            among: particles,
            at: date,
            in: size,
            context: &context
        )
    }

    private func drawOverlapGlints(
        among particles: [RainParticle],
        at date: Date,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let rings = visibleRingGeometries(
            for: particles,
            at: date,
            in: size
        )
        let glints = RainOverlapGlintGeometry.glints(for: rings)
        let intensityMultiplier = RainVisualIntensity.rippleOpacityMultiplier(
            for: intensity
        )

        for glint in glints {
            let opacity = min(
                glint.sourceOpacity
                    * 2.6
                    * glint.strength
                    * intensityMultiplier,
                0.78
            )
            guard opacity > 0.025 else { continue }

            let coreRadius = 0.75 + (CGFloat(glint.strength) * 0.65)
            let coreRect = CGRect(
                x: glint.position.x - coreRadius,
                y: glint.position.y - coreRadius,
                width: coreRadius * 2,
                height: coreRadius * 2
            )
            context.drawLayer { glowContext in
                glowContext.addFilter(.blur(radius: 2.0))
                let glowRadius = coreRadius * 2.5
                let glowRect = CGRect(
                    x: glint.position.x - glowRadius,
                    y: glint.position.y - glowRadius,
                    width: glowRadius * 2,
                    height: glowRadius * 2
                )
                glowContext.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(RainRipplePalette.moonlight.opacity(opacity * 0.55))
                )
            }
            context.fill(
                Path(ellipseIn: coreRect),
                with: .color(RainRipplePalette.moonlight.opacity(opacity))
            )
        }
    }

    private func visibleRingGeometries(
        for particles: [RainParticle],
        at date: Date,
        in size: CGSize
    ) -> [RainRingGeometry] {
        var rings: [RainRingGeometry] = []
        rings.reserveCapacity(particles.count * 2)

        for particle in particles where !particle.usesReducedMotion {
            let elapsed = date.timeIntervalSince(particle.startedAt)
            guard elapsed >= 0, elapsed <= particle.totalLifetime else { continue }

            let style = particle.style
            let particleCenter = CGPoint(
                x: particle.position.x * size.width,
                y: particle.position.y * size.height
            )
            for ringIndex in 0..<style.ringCount {
                let ringElapsed = elapsed
                    - (Double(ringIndex) * style.secondaryRingDelay)
                guard ringElapsed >= 0,
                      ringElapsed <= particle.animationLifetime else {
                    continue
                }

                let progress = min(
                    max(ringElapsed / particle.animationLifetime, 0),
                    1
                )
                let easedProgress = 1 - pow(1 - progress, 2)
                let radius = style.initialRadius
                    + (((style.finalRadius * particle.radiusScale)
                        - style.initialRadius) * CGFloat(easedProgress))
                let fadeIn = min(ringElapsed / 0.07, 1)
                let secondaryStrength = ringIndex == 0 ? 1.0 : 0.58
                let opacity = style.peakOpacity
                    * fadeIn
                    * pow(1 - progress, 0.92)
                    * secondaryStrength
                    * particle.opacityScale
                guard opacity > 0.01 else { continue }

                rings.append(RainRingGeometry(
                    particleID: particle.id,
                    center: CGPoint(
                        x: particleCenter.x,
                        y: particleCenter.y
                            + (style.verticalDrift * CGFloat(progress))
                    ),
                    radius: radius,
                    opacity: opacity
                ))
            }
        }
        return rings
    }

    private func drawAnimatedParticle(
        _ particle: RainParticle,
        elapsed: TimeInterval,
        center: CGPoint,
        context: inout GraphicsContext
    ) {
        let style = particle.style
        for ringIndex in 0..<style.ringCount {
            let ringElapsed = elapsed - (Double(ringIndex) * style.secondaryRingDelay)
            guard ringElapsed >= 0, ringElapsed <= particle.animationLifetime else { continue }

            let progress = min(max(ringElapsed / particle.animationLifetime, 0), 1)
            let easedProgress = 1 - pow(1 - progress, 2)
            let radius = style.initialRadius
                + (((style.finalRadius * particle.radiusScale) - style.initialRadius)
                    * CGFloat(easedProgress))
            let fadeIn = min(ringElapsed / 0.07, 1)
            let secondaryStrength = ringIndex == 0 ? 1.0 : 0.58
            let opacity = style.peakOpacity
                * fadeIn
                * pow(1 - progress, 0.92)
                * secondaryStrength
                * particle.opacityScale
                * RainVisualIntensity.rippleOpacityMultiplier(for: intensity)
            let drift = style.verticalDrift * CGFloat(progress)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y + drift - radius,
                width: radius * 2,
                height: radius * 2
            )
            strokeRipple(
                Path(ellipseIn: rect),
                color: RainRipplePalette.color(
                    for: style,
                    ringIndex: ringIndex,
                    isFeatured: particle.isFeatured
                ),
                opacity: opacity,
                baseLineWidth: style.lineWidth * particle.lineWidthScale,
                isFeatured: particle.isFeatured,
                context: &context
            )
        }

        if elapsed <= RainVisualTuning.impactPointLifetime {
            let progress = elapsed / RainVisualTuning.impactPointLifetime
            let opacity = style.peakOpacity
                * 0.9
                * (1 - progress)
                * particle.opacityScale
                * RainVisualIntensity.rippleOpacityMultiplier(for: intensity)
            let radius = style.impactPointRadius * particle.lineWidthScale
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(
                    RainRipplePalette.color(for: style, isFeatured: particle.isFeatured)
                        .opacity(min(max(opacity, 0), 1))
                )
            )
        }
    }

    private func drawReducedMotionParticle(
        _ particle: RainParticle,
        elapsed: TimeInterval,
        center: CGPoint,
        context: inout GraphicsContext
    ) {
        let progress = min(max(elapsed / particle.totalLifetime, 0), 1)
        let opacity = particle.style.peakOpacity
            * 0.72
            * sin(.pi * progress)
            * particle.opacityScale
            * RainVisualIntensity.rippleOpacityMultiplier(for: intensity)
        let radius = (particle.style.initialRadius + 2) * particle.radiusScale
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        strokeRipple(
            Path(ellipseIn: rect),
            color: RainRipplePalette.color(
                for: particle.style,
                isFeatured: particle.isFeatured
            ),
            opacity: opacity,
            baseLineWidth: particle.style.lineWidth * particle.lineWidthScale,
            isFeatured: particle.isFeatured,
            context: &context
        )
    }

    private func drawEcho(
        for particle: RainParticle,
        elapsed: TimeInterval,
        center: CGPoint,
        context: inout GraphicsContext
    ) {
        let echoElapsed = elapsed - RainRippleSurprise.echoDelay
        let lifetime = particle.usesReducedMotion
            ? RainRippleSurprise.reducedMotionEchoLifetime
            : RainRippleSurprise.echoLifetime
        guard echoElapsed >= 0, echoElapsed <= lifetime else { return }

        let progress = min(max(echoElapsed / lifetime, 0), 1)
        let radius: CGFloat
        let opacityCurve: Double
        if particle.usesReducedMotion {
            radius = particle.echoFinalRadius * 0.56
            opacityCurve = sin(.pi * progress)
        } else {
            let easedProgress = 1 - pow(1 - progress, 2)
            radius = RainRippleSurprise.echoInitialRadius
                + ((particle.echoFinalRadius
                    - RainRippleSurprise.echoInitialRadius) * CGFloat(easedProgress))
            let fadeIn = min(echoElapsed / 0.055, 1)
            opacityCurve = fadeIn * pow(1 - progress, 1.05)
        }

        let opacity = particle.style.peakOpacity
            * 0.88
            * opacityCurve
            * RainVisualIntensity.rippleOpacityMultiplier(for: intensity)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        strokeRipple(
            Path(ellipseIn: rect),
            color: RainRipplePalette.color(
                for: particle.style,
                isFeatured: true
            ),
            opacity: opacity,
            baseLineWidth: RainRippleSurprise.echoLineWidth,
            isFeatured: true,
            context: &context
        )
    }

    private func drawAlwaysOnParticle(
        _ particle: RainParticle,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let center = CGPoint(
            x: particle.position.x * size.width,
            y: particle.position.y * size.height
        )
        let radius = particle.style.initialRadius
            + (((particle.style.finalRadius * particle.radiusScale)
                - particle.style.initialRadius) * 0.72)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let opacity = particle.style.peakOpacity
            * 0.8
            * particle.opacityScale
            * RainVisualIntensity.rippleOpacityMultiplier(for: intensity)

        strokeRipple(
            Path(ellipseIn: rect),
            color: RainRipplePalette.color(
                for: particle.style,
                isFeatured: particle.isFeatured
            ),
            opacity: opacity,
            baseLineWidth: particle.style.lineWidth * particle.lineWidthScale,
            isFeatured: particle.isFeatured,
            context: &context
        )

        if let echoPosition = particle.echoPosition {
            let echoCenter = CGPoint(
                x: echoPosition.x * size.width,
                y: echoPosition.y * size.height
            )
            let radius = particle.echoFinalRadius * 0.68
            let rect = CGRect(
                x: echoCenter.x - radius,
                y: echoCenter.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            strokeRipple(
                Path(ellipseIn: rect),
                color: RainRipplePalette.color(
                    for: particle.style,
                    isFeatured: true
                ),
                opacity: particle.style.peakOpacity
                    * 0.5
                    * RainVisualIntensity.rippleOpacityMultiplier(for: intensity),
                baseLineWidth: RainRippleSurprise.echoLineWidth,
                isFeatured: true,
                context: &context
            )
        }
    }

    private func strokeRipple(
        _ path: Path,
        color: Color,
        opacity: Double,
        baseLineWidth: CGFloat,
        isFeatured: Bool = false,
        context: inout GraphicsContext
    ) {
        let opacity = min(max(opacity, 0), 1)
        let lineWidth = baseLineWidth
            * CGFloat(RainVisualIntensity.lineWidthMultiplier(for: intensity))
        let glowStrength = max(
            RainVisualIntensity.glowStrength(for: intensity),
            isFeatured ? RainRippleSurprise.glowStrength : 0
        )

        if glowStrength > 0 {
            context.drawLayer { glowContext in
                glowContext.addFilter(.blur(radius: 2.2))
                glowContext.stroke(
                    path,
                    with: .color(color.opacity(opacity * glowStrength)),
                    lineWidth: lineWidth * 1.9
                )
            }
        }

        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            lineWidth: lineWidth
        )
    }
}

#if DEBUG
struct RainSurfaceDebugHarness: View {
    @State private var events: [HapticVisualEvent] = []

    var body: some View {
        RainSurfaceView(
            events: events,
            isSessionActive: true,
            intensity: RainVisualIntensity.defaultValue,
            hitsPerPulse: 7
        )
            .ignoresSafeArea()
            .task {
                guard events.isEmpty else { return }
                let sequence: [WKHapticType] = [
                    .success, .directionUp, .directionDown,
                    .click, .click, .click, .click
                ]
                while !Task.isCancelled {
                    let pulseID = UUID()
                    for (index, type) in sequence.enumerated() {
                        events.append(HapticVisualEvent(
                            pulseID: pulseID,
                            hitIndex: index,
                            hapticType: type,
                            positionSeed: UInt64.random(in: .min ... .max)
                        ))
                        if events.count > 16 {
                            events.removeFirst(events.count - 16)
                        }
                        try? await Task.sleep(for: .milliseconds(index < 3 ? 420 : 120))
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
    }
}

#Preview("Still Rain") {
    RainSurfaceDebugHarness()
}
#endif
