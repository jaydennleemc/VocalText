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
            iconColor: .accentPrimary
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step2.title", comment: ""),
            description: NSLocalizedString("tutorial.step2.description", comment: ""),
            icon: "mic.circle.fill",
            iconColor: .recordingRed
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step3.title", comment: ""),
            description: NSLocalizedString("tutorial.step3.description", comment: ""),
            icon: "text.bubble.fill",
            iconColor: .successGreen
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step4.title", comment: ""),
            description: NSLocalizedString("tutorial.step4.description", comment: ""),
            icon: "gearshape.fill",
            iconColor: .accentPurple
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step5.title", comment: ""),
            description: NSLocalizedString("tutorial.step5.description", comment: ""),
            icon: "checkmark.circle.fill",
            iconColor: .successGreen
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header with skip button
            HStack {
                Spacer()
                Button(action: skipTutorial) {
                    Text("tutorial.skip.button")
                        .font(.system(size: AppConstants.UI.fontBody))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, AppConstants.UI.spacingXS)
                        .padding(.vertical, AppConstants.UI.spacingXXS)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, AppConstants.UI.spacingSM)
            .padding(.top, AppConstants.UI.spacingXS)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.bgHover)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentGradient)
                        .frame(width: geometry.size.width * CGFloat(currentStep + 1) / CGFloat(steps.count), height: 4)
                        .animation(.spring(response: AppConstants.Animation.springResponse), value: currentStep)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, AppConstants.UI.spacingMD)
            .padding(.top, AppConstants.UI.spacingXS)

            // Main content
            ZStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    TutorialStepView(step: steps[index])
                        .opacity(currentStep == index ? 1 : 0)
                        .scaleEffect(currentStep == index ? 1 : 0.9)
                        .animation(.spring(response: AppConstants.Animation.springResponse, dampingFraction: 0.85), value: currentStep)
                }
            }
            .frame(maxHeight: .infinity)

            // Bottom controls
            VStack(spacing: AppConstants.UI.spacingMD) {
                // Step dots
                HStack(spacing: AppConstants.UI.spacingXS) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentStep ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.bgHover))
                            .frame(width: index == currentStep ? 20 : 8, height: 8)
                            .animation(.spring(response: AppConstants.Animation.springResponse), value: currentStep)
                    }
                }

                // Navigation buttons
                HStack(spacing: AppConstants.UI.spacingSM) {
                    if currentStep > 0 {
                        Button(action: previousStep) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: AppConstants.UI.iconSmall, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(Color.bgHover)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Button(action: nextStep) {
                        HStack(spacing: 6) {
                            Text(currentStep == steps.count - 1 ? "tutorial.start.using.button" : "tutorial.next.button")
                                .font(.system(size: AppConstants.UI.fontBody, weight: .semibold))
                            if currentStep < steps.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: AppConstants.UI.fontCaption, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, AppConstants.UI.spacingLG)
                        .padding(.vertical, AppConstants.UI.spacingSM)
                        .background(Color.accentGradient)
                        .clipShape(Capsule())
                        .shadow(color: .accentGlow, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, AppConstants.UI.spacingLG)
            .padding(.bottom, AppConstants.UI.spacingLG)
        }
        .frame(width: AppConstants.UI.windowWidth, height: AppConstants.UI.tutorialHeight)
        .background(Color.bgSecondary)
    }

    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation(.spring(response: AppConstants.Animation.springResponse, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            completeTutorial()
        }
    }

    private func previousStep() {
        if currentStep > 0 {
            withAnimation(.spring(response: AppConstants.Animation.springResponse, dampingFraction: 0.8)) {
                currentStep -= 1
            }
        }
    }

    private func skipTutorial() {
        UserDefaults.standard.set(true, forKey: "HasCompletedTutorial")
        onTutorialCompleted?()
        withAnimation(.easeOut(duration: AppConstants.Animation.fadeOutDuration)) {
            isPresented = false
        }
    }

    private func completeTutorial() {
        UserDefaults.standard.set(true, forKey: "HasCompletedTutorial")
        onTutorialCompleted?()
        withAnimation(.easeOut(duration: AppConstants.Animation.fadeOutDuration)) {
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
        VStack(spacing: AppConstants.UI.spacingLG) {
            Spacer()

            // Animated icon with gradient circle
            ZStack {
                Circle()
                    .fill(Color.tutorialGradient)
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

            VStack(spacing: AppConstants.UI.spacingXS) {
                Text(step.title)
                    .font(.system(size: AppConstants.UI.fontTitle, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.system(size: AppConstants.UI.fontBodyLarge))
                    .foregroundColor(.textSecondary)
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
        .padding(.horizontal, AppConstants.UI.spacingLG)
    }
}

#Preview {
    TutorialView(isPresented: .constant(true))
}
