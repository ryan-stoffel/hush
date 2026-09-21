import HushCore
import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayViewModel

    var body: some View {
        HStack(spacing: 10) {
            switch model.mode {
            case .listening:
                WaveformBars(heights: model.waveform.barHeights)
                    .frame(width: 120, height: 22)
                Text(model.elapsedText)
                    .monospacedDigit()
                    .accessibilityIdentifier("overlay.elapsed")
            case .transcribing:
                ProgressView()
                    .controlSize(.small)
                    .colorScheme(.dark)
                Text("Transcribing")
            case let .error(message):
                Text(message)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(minWidth: 180, minHeight: 40)
        .background(Capsule().fill(Color.black.opacity(0.85)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        .padding(6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("overlay.root")
    }
}

private struct WaveformBars: View {
    let heights: [Float]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                    Capsule()
                        .fill(Color.white)
                        .frame(height: max(proxy.size.height * CGFloat(height), 2))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}
