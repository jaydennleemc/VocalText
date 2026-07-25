//
//  RecordingButtonView.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

// MARK: - Recording Button

struct RecordingButton: View {
    let isRecording: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer pulse ring when recording
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                                pulseScale = 1.3
                            }
                        }
                        .onDisappear {
                            pulseScale = 1.0
                        }
                }

                // Button background with gradient
                Circle()
                    .fill(isRecording ? AnyShapeStyle(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(LinearGradient(colors: [.accentColor, .purple], startPoint: .leading, endPoint: .trailing)))
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: (isRecording ? Color.red.opacity(0.3) : Color.accentColor.opacity(0.3)),
                        radius: isPressed ? 6 : 12,
                        x: 0,
                        y: isPressed ? 2 : 6
                    )

                // Icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}