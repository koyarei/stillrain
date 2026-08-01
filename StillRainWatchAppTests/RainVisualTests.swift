import WatchKit
import XCTest
@testable import StillRainWatchApp

final class RippleStyleTests: XCTestCase {
    func testSupportedHapticTypesUseExpectedStyles() {
        XCTAssertEqual(RippleStyle.style(for: .click), .click)
        XCTAssertEqual(RippleStyle.style(for: .directionDown), .directionDown)
        XCTAssertEqual(RippleStyle.style(for: .directionUp), .directionUp)
        XCTAssertEqual(RippleStyle.style(for: .start), .transition)
        XCTAssertEqual(RippleStyle.style(for: .stop), .transition)
        XCTAssertEqual(RippleStyle.style(for: .success), .success)
    }

    func testOtherSupportedTypesUseRestrainedClickFallback() {
        XCTAssertEqual(RippleStyle.style(for: .failure), .click)
    }

    func testStylesFollowWristCalibratedStrengthOrder() {
        let styles: [RippleStyle] = [
            .click,
            .transition,
            .directionDown,
            .directionUp,
            .success
        ]

        XCTAssertEqual(styles.map(\.perceivedStrength), [1, 2, 3, 4, 5])
        XCTAssertEqual(styles.map(\.finalRadius), [16, 21, 27, 34, 41])
        for (weaker, stronger) in zip(styles, styles.dropFirst()) {
            XCTAssertLessThan(weaker.finalRadius, stronger.finalRadius)
            XCTAssertLessThan(weaker.peakOpacity, stronger.peakOpacity)
            XCTAssertLessThan(weaker.lineWidth, stronger.lineWidth)
            XCTAssertLessThan(weaker.lifetime, stronger.lifetime)
        }
    }
}

final class RainPositionGeneratorTests: XCTestCase {
    func testPositionIsDeterministicForSeedAndHitIndex() {
        let first = RainPositionGenerator.normalizedPosition(seed: 123_456, hitIndex: 3)
        let second = RainPositionGenerator.normalizedPosition(seed: 123_456, hitIndex: 3)

        XCTAssertEqual(first.x, second.x, accuracy: 0.000_001)
        XCTAssertEqual(first.y, second.y, accuracy: 0.000_001)
    }

    func testHitsInPulseUseDistinctNormalizedPositions() {
        let positions = (0..<6).map {
            RainPositionGenerator.normalizedPosition(seed: 0xA11CE, hitIndex: $0)
        }

        XCTAssertEqual(Set(positions.map { "\($0.x),\($0.y)" }).count, 6)
        XCTAssertTrue(positions.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }

    func testMotifsRemainOccasionalAndSelectionIsDeterministic() {
        let seeds = (0..<512).map(UInt64.init)
        let firstSelections = seeds.map {
            RainSpatialMotif.selection(seed: $0, hitCount: 8)
        }
        let secondSelections = seeds.map {
            RainSpatialMotif.selection(seed: $0, hitCount: 8)
        }

        XCTAssertEqual(firstSelections, secondSelections)
        for motif in RainSpatialMotif.allCases {
            XCTAssertTrue(firstSelections.contains(motif))
        }
        XCTAssertGreaterThan(
            firstSelections.filter { $0 == .organic }.count,
            firstSelections.filter { $0 != .organic }.count
        )
    }

    func testFewerThanFourHitsAlwaysUseOrganicPlacement() {
        for hitCount in 1...3 {
            for seed in 0..<64 {
                XCTAssertEqual(
                    RainSpatialMotif.selection(
                        seed: UInt64(seed),
                        hitCount: hitCount
                    ),
                    .organic
                )
            }
        }
    }

    func testEveryMotifProducesDistinctInBoundsPositions() {
        for motif in RainSpatialMotif.allCases where motif != .organic {
            let positions = (0..<12).map {
                RainPositionGenerator.normalizedPosition(
                    seed: 0xC011EC7,
                    hitIndex: $0,
                    hitCount: 12,
                    motif: motif
                )
            }

            XCTAssertEqual(
                Set(positions.map { "\($0.x),\($0.y)" }).count,
                positions.count,
                "\(motif) should not repeat a point"
            )
            XCTAssertTrue(positions.allSatisfy {
                (0.08...0.92).contains($0.x) && (0.08...0.92).contains($0.y)
            })
        }
    }
}

final class RainOverlapGlintGeometryTests: XCTestCase {
    func testEqualRingsProduceTwoExpectedIntersectionGlints() {
        let firstID = UUID()
        let secondID = UUID()
        let glints = RainOverlapGlintGeometry.glints(for: [
            ring(id: firstID, x: 0, y: 0, radius: 5),
            ring(id: secondID, x: 8, y: 0, radius: 5)
        ])

        XCTAssertEqual(glints.count, 2)
        XCTAssertTrue(glints.contains {
            abs($0.position.x - 4) < 0.000_001
                && abs($0.position.y - 3) < 0.000_001
        })
        XCTAssertTrue(glints.contains {
            abs($0.position.x - 4) < 0.000_001
                && abs($0.position.y + 3) < 0.000_001
        })
    }

    func testGlintsAppearOnlyDuringEarlyCollisionWindow() {
        let firstID = UUID()
        let secondID = UUID()
        let separated = RainOverlapGlintGeometry.glints(for: [
            ring(id: firstID, x: 0, y: 0, radius: 5),
            ring(id: secondID, x: 12, y: 0, radius: 5)
        ])
        let deeplyOverlapped = RainOverlapGlintGeometry.glints(for: [
            ring(id: firstID, x: 0, y: 0, radius: 5),
            ring(id: secondID, x: 6, y: 0, radius: 5)
        ])

        XCTAssertTrue(separated.isEmpty)
        XCTAssertTrue(deeplyOverlapped.isEmpty)
    }

    func testRingsFromSameParticleDoNotCreateGlints() {
        let particleID = UUID()
        let glints = RainOverlapGlintGeometry.glints(for: [
            ring(id: particleID, x: 0, y: 0, radius: 5),
            ring(id: particleID, x: 8, y: 0, radius: 5)
        ])

        XCTAssertTrue(glints.isEmpty)
    }

    func testGlintCountIsCappedForRenderingBudget() {
        let rings = (0..<6).map {
            ring(id: UUID(), x: CGFloat($0 * 8), y: 0, radius: 5)
        }
        let glints = RainOverlapGlintGeometry.glints(for: rings)

        XCTAssertFalse(glints.isEmpty)
        XCTAssertLessThanOrEqual(
            glints.count,
            RainOverlapGlintGeometry.maximumGlintCount
        )
    }

    private func ring(
        id: UUID,
        x: CGFloat,
        y: CGFloat,
        radius: CGFloat
    ) -> RainRingGeometry {
        RainRingGeometry(
            particleID: id,
            center: CGPoint(x: x, y: y),
            radius: radius,
            opacity: 0.5
        )
    }
}

final class RainRippleSurpriseTests: XCTestCase {
    func testRepeatedPulseSelectsExactlyOneStableFeaturedHit() {
        let seed: UInt64 = 0xA11CE
        let firstSelection = RainRippleSurprise.featuredHitIndex(seed: seed, hitCount: 8)
        let secondSelection = RainRippleSurprise.featuredHitIndex(seed: seed, hitCount: 8)

        XCTAssertEqual(firstSelection, secondSelection)
        XCTAssertNotNil(firstSelection)
        XCTAssertTrue((0..<8).contains(firstSelection!))
    }

    func testSingleHitPulseHasNoFeaturedHit() {
        XCTAssertNil(RainRippleSurprise.featuredHitIndex(seed: 42, hitCount: 1))
    }

    func testEchoSelectionIsOccasionalAndDeterministic() throws {
        let center = CGPoint(x: 0.5, y: 0.5)
        let echoSeeds = (0..<120).compactMap { value -> UInt64? in
            let seed = UInt64(value)
            return RainRippleSurprise.echoPosition(seed: seed, around: center) == nil
                ? nil
                : seed
        }

        XCTAssertGreaterThan(echoSeeds.count, 0)
        XCTAssertLessThan(echoSeeds.count, 120)

        let seed = try XCTUnwrap(echoSeeds.first)
        let first = try XCTUnwrap(
            RainRippleSurprise.echoPosition(seed: seed, around: center)
        )
        let second = try XCTUnwrap(
            RainRippleSurprise.echoPosition(seed: seed, around: center)
        )
        XCTAssertEqual(first.x, second.x, accuracy: 0.000_001)
        XCTAssertEqual(first.y, second.y, accuracy: 0.000_001)
        XCTAssertEqual(RainRippleSurprise.echoDelay, 0.15)
        XCTAssertLessThan(hypot(first.x - center.x, first.y - center.y), 0.1)
    }
}

@MainActor
final class RainParticleStoreTests: XCTestCase {
    func testMaximumParticleCountRemovesOldestParticle() {
        let store = RainParticleStore(maximumParticleCount: 3)
        let now = Date()
        let events = (0..<5).map { event(hitIndex: $0, date: now, seed: UInt64($0)) }

        store.consume(
            events,
            visualStyle: .stillRain,
            reduceMotion: false,
            now: now
        )

        XCTAssertEqual(store.particles.count, 3)
        XCTAssertEqual(store.particles.map(\.id), events.suffix(3).map(\.id))
    }

    func testClearRemovesEveryParticleImmediately() {
        let store = RainParticleStore()
        let now = Date()
        store.consume(
            [event(date: now)],
            visualStyle: .stillRain,
            reduceMotion: false,
            now: now
        )

        store.clearParticles()

        XCTAssertTrue(store.particles.isEmpty)
    }

    func testDarkModeCreatesNoParticles() {
        let store = RainParticleStore()
        let now = Date()

        store.consume(
            [event(date: now)],
            visualStyle: .dark,
            reduceMotion: false,
            now: now
        )

        XCTAssertTrue(store.particles.isEmpty)
    }

    func testLatestParticleRemainsAvailableForAlwaysOnPresentation() {
        let store = RainParticleStore()
        let now = Date()
        let latestEvent = event(date: now)
        store.consume(
            [latestEvent],
            visualStyle: .stillRain,
            reduceMotion: false,
            now: now
        )
        store.clearParticles()

        XCTAssertTrue(store.particles.isEmpty)
        XCTAssertEqual(store.latestParticle?.id, latestEvent.id)
    }

    func testExactlyOneRippleIsFeaturedInRepeatedPulse() {
        let store = RainParticleStore(maximumParticleCount: 8)
        let now = Date()
        let pulseID = UUID()
        let events = (0..<8).map {
            event(
                pulseID: pulseID,
                hitIndex: $0,
                date: now,
                seed: 0xA11CE
            )
        }

        store.consume(
            events,
            visualStyle: .stillRain,
            reduceMotion: false,
            hitsPerPulse: 8,
            now: now
        )

        XCTAssertEqual(store.particles.filter(\.isFeatured).count, 1)
    }

    func testCompoundHapticIsNotFeaturedByRepeatSetting() {
        let store = RainParticleStore()
        let now = Date()
        let event = HapticVisualEvent(
            pulseID: UUID(),
            hitIndex: 0,
            hapticType: .success,
            occurredAt: now,
            positionSeed: 42
        )

        store.consume(
            [event],
            visualStyle: .stillRain,
            reduceMotion: false,
            hitsPerPulse: 8,
            now: now
        )

        XCTAssertEqual(store.particles.first?.isFeatured, false)
        XCTAssertNil(store.particles.first?.echoPosition)
    }

    func testParticleStorePreservesSelectedMotifGeometry() throws {
        let store = RainParticleStore(maximumParticleCount: 8)
        let now = Date()
        let seed = try XCTUnwrap((0..<100).map(UInt64.init).first {
            RainSpatialMotif.selection(seed: $0, hitCount: 8) != .organic
        })
        let motif = RainSpatialMotif.selection(seed: seed, hitCount: 8)
        let pulseID = UUID()
        let events = (0..<8).map {
            event(
                pulseID: pulseID,
                hitIndex: $0,
                date: now,
                seed: seed
            )
        }

        store.consume(
            events,
            visualStyle: .stillRain,
            reduceMotion: false,
            hitsPerPulse: 8,
            now: now
        )

        XCTAssertEqual(store.particles.count, events.count)
        for (particle, hitIndex) in zip(store.particles, events.indices) {
            let expected = RainPositionGenerator.normalizedPosition(
                seed: seed,
                hitIndex: hitIndex,
                hitCount: 8,
                motif: motif
            )
            XCTAssertEqual(particle.position.x, expected.x, accuracy: 0.000_001)
            XCTAssertEqual(particle.position.y, expected.y, accuracy: 0.000_001)
        }
    }

    func testFeaturedRippleLivesLongerThanOrdinaryRipple() {
        let store = RainParticleStore(maximumParticleCount: 8)
        let now = Date()
        let seed: UInt64 = 0xA11CE
        let pulseID = UUID()
        let events = (0..<8).map {
            event(pulseID: pulseID, hitIndex: $0, date: now, seed: seed)
        }

        store.consume(
            events,
            visualStyle: .stillRain,
            reduceMotion: false,
            hitsPerPulse: 8,
            now: now
        )

        let featured = store.particles.first(where: \.isFeatured)
        let ordinary = store.particles.first { !$0.isFeatured }
        XCTAssertGreaterThan(featured!.totalLifetime, ordinary!.totalLifetime)
        XCTAssertGreaterThan(featured!.radiusScale, ordinary!.radiusScale)
    }

    func testOnlyFeaturedRippleCanReceiveEcho() throws {
        let store = RainParticleStore(maximumParticleCount: 8)
        let now = Date()
        let center = CGPoint(x: 0.5, y: 0.5)
        let seed = try XCTUnwrap((0..<100).map(UInt64.init).first {
            RainRippleSurprise.echoPosition(seed: $0, around: center) != nil
        })
        let pulseID = UUID()
        let events = (0..<8).map {
            event(pulseID: pulseID, hitIndex: $0, date: now, seed: seed)
        }

        store.consume(
            events,
            visualStyle: .stillRain,
            reduceMotion: false,
            hitsPerPulse: 8,
            now: now
        )

        let echoed = store.particles.filter { $0.echoPosition != nil }
        XCTAssertEqual(echoed.count, 1)
        XCTAssertTrue(try XCTUnwrap(echoed.first).isFeatured)
    }

    private func event(
        pulseID: UUID = UUID(),
        hitIndex: Int = 0,
        date: Date,
        seed: UInt64 = 17
    ) -> HapticVisualEvent {
        HapticVisualEvent(
            pulseID: pulseID,
            hitIndex: hitIndex,
            hapticType: .click,
            occurredAt: date,
            positionSeed: seed
        )
    }
}

final class RainVisualIntensityTests: XCTestCase {
    func testIntensityClampsToSupportedCrownRange() {
        XCTAssertEqual(RainVisualIntensity.clamped(-0.4), 0)
        XCTAssertEqual(RainVisualIntensity.clamped(0.65), 0.65)
        XCTAssertEqual(RainVisualIntensity.clamped(1.4), 1)
    }

    func testZeroIntensityProducesTrueBlackAndInvisibleRipples() {
        XCTAssertEqual(RainVisualIntensity.surfaceOpacity(for: 0), 0)
        XCTAssertEqual(RainVisualIntensity.rippleOpacityMultiplier(for: 0), 0)
    }

    func testDefaultIntensityPreservesOriginalAppearance() {
        XCTAssertEqual(
            RainVisualIntensity.surfaceOpacity(for: RainVisualIntensity.defaultValue),
            1
        )
        XCTAssertEqual(
            RainVisualIntensity.rippleOpacityMultiplier(for: RainVisualIntensity.defaultValue),
            1
        )
    }

    func testMaximumIntensityStrengthensRipples() {
        XCTAssertEqual(
            RainVisualIntensity.rippleOpacityMultiplier(for: 1),
            RainVisualIntensity.maximumRippleOpacityMultiplier
        )
    }

    func testUpperHalfProvidesAdditionalContrastBeyondOriginalMaximum() {
        XCTAssertGreaterThan(
            RainVisualIntensity.rippleOpacityMultiplier(for: 0.75),
            2
        )
    }

    func testDefaultIntensityKeepsOriginalStrokeAndNoGlow() {
        XCTAssertEqual(
            RainVisualIntensity.lineWidthMultiplier(for: RainVisualIntensity.defaultValue),
            1
        )
        XCTAssertEqual(
            RainVisualIntensity.glowStrength(for: RainVisualIntensity.defaultValue),
            0
        )
    }

    func testMaximumIntensityUsesThickerStrokeAndGlow() {
        XCTAssertEqual(
            RainVisualIntensity.lineWidthMultiplier(for: 1),
            RainVisualIntensity.maximumLineWidthMultiplier
        )
        XCTAssertEqual(
            RainVisualIntensity.glowStrength(for: 1),
            RainVisualIntensity.maximumGlowStrength
        )
    }
}
