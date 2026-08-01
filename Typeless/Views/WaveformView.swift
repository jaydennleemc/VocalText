//
//  WaveformView.swift
//  Typeless
//

import SwiftUI

// MARK: - Live waveform

struct VoiceMemoWaveformView: View {
    let volumeLevel: Double
    @State private var bars: [CGFloat] = Array(repeating: 0.08, count: 40)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<bars.count, id: \.self) { index in
                Capsule()
                    .fill(Color.red.gradient.opacity(0.85))
                    .frame(width: 3.5, height: max(3, bars[index] * 68))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .onReceive(Timer.publish(every: reduceMotion ? 0.12 : 0.05, on: .main, in: .common).autoconnect()) { _ in
            advanceBars()
        }
        .onChange(of: volumeLevel) { _ in
            if !bars.isEmpty {
                bars[bars.count - 1] = CGFloat(min(1.0, volumeLevel * Double.random(in: 0.85...1.15)))
            }
        }
    }

    private func advanceBars() {
        bars.removeFirst()
        bars.append(CGFloat(volumeLevel))
        guard bars.count >= 3 else { return }
        for i in 1..<bars.count - 1 {
            bars[i] = (bars[i - 1] + bars[i] + bars[i + 1]) / 3
        }
    }
}
