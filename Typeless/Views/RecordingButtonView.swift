//
//  RecordingButtonView.swift
//  Typeless
//

import SwiftUI

// MARK: - Recording Button

struct RecordingButton: View {
    let isRecording: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording && !reduceMotion {
                    Circle()
                        .stroke(Color.red.opacity(0.35), lineWidth: 2)
                        .frame(width: 74, height: 74)
                        .scaleEffect(isRecording ? 1.12 : 1.0)
                        .opacity(isRecording ? 0.55 : 1)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isRecording)
                }

                Circle()
                    .fill(isRecording ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(Color.accentColor.gradient))
                    .frame(width: 58, height: 58)
                    .shadow(
                        color: (isRecording ? Color.red : Color.accentColor).opacity(isPressed ? 0.25 : 0.4),
                        radius: isPressed ? 6 : 14,
                        y: isPressed ? 2 : 6
                    )

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 74, height: 74)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .scaleEffect(isPressed ? 0.94 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isPressed)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isRecording)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .help(isRecording ? "Stop recording" : "Start recording")
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}
