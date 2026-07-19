//
//  WaveformView.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

// MARK: - Waveform Views

struct VoiceMemoWaveformView: View {
    @Binding var volumeLevel: Double
    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: AppConstants.Recording.waveformBarCount)
    @State private var lastVolumeUpdate: Date = Date()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.recordingRed, .recordingRed.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: AppConstants.UI.waveformBarWidth, height: max(2, bars[index] * AppConstants.UI.waveformHeight))
                    .animation(.easeOut(duration: AppConstants.Animation.waveformBarDuration), value: bars[index])
            }
        }
        .frame(height: AppConstants.UI.waveformHeight)
        .onReceive(Timer.publish(every: AppConstants.Recording.waveformTimerInterval, on: .main, in: .common).autoconnect()) { _ in
            updateBars()
        }
        .onChange(of: volumeLevel) { _ in
            updateBarsWithVolume()
        }
    }

    private func updateBars() {
        bars.removeFirst()
        let newBarHeight = CGFloat(volumeLevel)
        bars.append(newBarHeight)

        if bars.count >= 3 {
            for i in 1..<bars.count-1 {
                bars[i] = (bars[i-1] + bars[i] + bars[i+1]) / 3
            }
        }
    }

    private func updateBarsWithVolume() {
        if !bars.isEmpty {
            let randomFactor = Double.random(in: 0.8...1.2)
            let adjustedVolume = volumeLevel * randomFactor
            let newBarHeight = CGFloat(min(1.0, adjustedVolume))
            bars[bars.count - 1] = newBarHeight

            let index = bars.count - 1
            if index >= 2 {
                for i in (index - 2)..<index {
                    if i > 0 && i < bars.count - 1 {
                        bars[i] = (bars[i-1] + bars[i] + bars[i+1]) / 3
                    }
                }
            }
        }
    }
}
