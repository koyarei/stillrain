import SwiftUI

struct DarkIdleView: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
    }
}

struct NaturalCompletionView: View {
    let intensity: Double
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black
            SlowCenterRipple(intensity: intensity)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session complete")
        .accessibilityHint("Tap to return to the main screen")
        .accessibilityAddTraits(.isButton)
    }
}

private struct SlowCenterRipple: View {
    let intensity: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var startedAt = Date()

    private let expansionDuration: TimeInterval = 4.2
    private let pauseDuration: TimeInterval = 0.8
    private let initialRadius: CGFloat = 4
    private let basePeakOpacity = 0.27
    private let baseLineWidth: CGFloat = 1.15

    var body: some View {
        GeometryReader { _ in
            if reduceMotion || isLuminanceReduced {
                staticRipple
            } else {
                TimelineView(.animation(
                    minimumInterval: RainVisualTuning.minimumFrameInterval,
                    paused: false
                )) { timeline in
                    Canvas { context, size in
                        drawAnimatedRipple(at: timeline.date, in: size, context: &context)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var staticRipple: some View {
        Canvas { context, canvasSize in
            let finalRadius = min(canvasSize.width, canvasSize.height) * 0.42
            drawRipple(
                radius: finalRadius * 0.68,
                opacity: scaledOpacity(basePeakOpacity * 0.55),
                in: canvasSize,
                context: &context
            )
        }
    }

    private func drawAnimatedRipple(
        at date: Date,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let cycleDuration = expansionDuration + pauseDuration
        let elapsed = max(0, date.timeIntervalSince(startedAt))
            .truncatingRemainder(dividingBy: cycleDuration)
        guard elapsed <= expansionDuration else { return }

        let progress = min(max(elapsed / expansionDuration, 0), 1)
        let easedProgress = 1 - pow(1 - progress, 2)
        let finalRadius = min(size.width, size.height) * 0.42
        let radius = initialRadius
            + ((finalRadius - initialRadius) * CGFloat(easedProgress))
        let fadeIn = min(elapsed / 0.3, 1)
        let opacity = scaledOpacity(
            basePeakOpacity * fadeIn * pow(1 - progress, 0.72)
        )

        drawRipple(
            radius: radius,
            opacity: opacity,
            in: size,
            context: &context
        )
    }

    private func scaledOpacity(_ opacity: Double) -> Double {
        min(
            max(
                opacity * RainVisualIntensity.rippleOpacityMultiplier(for: intensity),
                0
            ),
            1
        )
    }

    private func drawRipple(
        radius: CGFloat,
        opacity: Double,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let path = Path(ellipseIn: rect)
        let lineWidth = baseLineWidth
            * CGFloat(RainVisualIntensity.lineWidthMultiplier(for: intensity))
        let glowStrength = RainVisualIntensity.glowStrength(for: intensity)

        if glowStrength > 0 {
            context.drawLayer { glowContext in
                glowContext.addFilter(.blur(radius: 2.2))
                glowContext.stroke(
                    path,
                    with: .color(
                        RainRipplePalette.skyBlue.opacity(opacity * glowStrength)
                    ),
                    lineWidth: lineWidth * 1.9
                )
            }
        }

        context.stroke(
            path,
            with: .color(RainRipplePalette.skyBlue.opacity(opacity)),
            lineWidth: lineWidth
        )
    }
}
