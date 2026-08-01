//
//  TutorialView.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

// MARK: - Tutorial Step Model

struct TutorialStep {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
}

// MARK: - Tutorial View

struct TutorialView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    var onTutorialCompleted: (() -> Void)? = nil

    let steps = [
        TutorialStep(
            title: NSLocalizedString("tutorial.step1.title", comment: ""),
            description: NSLocalizedString("tutorial.step1.description", comment: ""),
            icon: "waveform",
            iconColor: .accentColor
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step2.title", comment: ""),
            description: NSLocalizedString("tutorial.step2.description", comment: ""),
            icon: "mic.circle.fill",
            iconColor: .red
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step3.title", comment: ""),
            description: NSLocalizedString("tutorial.step3.description", comment: ""),
            icon: "text.bubble.fill",
            iconColor: .green
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step4.title", comment: ""),
            description: NSLocalizedString("tutorial.step4.description", comment: ""),
            icon: "gearshape.fill",
            iconColor: .purple
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step5.title", comment: ""),
            description: NSLocalizedString("tutorial.step5.description", comment: ""),
            icon: "checkmark.circle.fill",
            iconColor: .green
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header with skip button
            HStack {
                Spacer()
                Button(action: skipTutorial) {
                    Text("tutorial.skip.button")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(colors: [.accentColor, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geometry.size.width * CGFloat(currentStep + 1) / CGFloat(steps.count), height: 4)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Main content
            ZStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    TutorialStepView(step: steps[index])
                        .opacity(currentStep == index ? 1 : 0)
                        .scaleEffect(currentStep == index ? 1 : 0.9)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
                }
            }
            .frame(maxHeight: .infinity)

            // Bottom controls
            VStack(spacing: 16) {
                // Step dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentStep ? AnyShapeStyle(LinearGradient(colors: [.accentColor, .purple], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)))
                            .frame(width: index == currentStep ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }

                // Navigation buttons
                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button(action: previousStep) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 40, height: 40)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Button(action: nextStep) {
                        HStack(spacing: 6) {
                            Text(currentStep == steps.count - 1 ? "tutorial.start.using.button" : "tutorial.next.button")
                                .font(.system(size: 13, weight: .semibold))
                            if currentStep < steps.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(colors: [.accentColor, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 420, height: 400)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            completeTutorial()
        }
    }

    private func previousStep() {
        if currentStep > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep -= 1
            }
        }
    }

    private func skipTutorial() {
        UserDefaults.standard.set(true, forKey: "HasCompletedTutorial")
        onTutorialCompleted?()
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }

    private func completeTutorial() {
        UserDefaults.standard.set(true, forKey: "HasCompletedTutorial")
        onTutorialCompleted?()
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
}

// MARK: - Tutorial Step View

struct TutorialStepView: View {
    let step: TutorialStep
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOffset: CGFloat = 20

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated icon with gradient circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: step.icon)
                    .font(.system(size: 44))
                    .foregroundColor(step.iconColor)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    iconScale = 1.0
                    iconOpacity = 1.0
                }
            }
            .onDisappear {
                iconScale = 0.5
                iconOpacity = 0
            }

            VStack(spacing: 8) {
                Text(step.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 280)
                    .offset(y: textOffset)
                    .opacity(1 - Double(textOffset) / 20)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    textOffset = 0
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    TutorialView(isPresented: .constant(true))
}