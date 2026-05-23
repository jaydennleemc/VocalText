import SwiftUI

// MARK: - Card Style Modifier

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.radiusMD)
                    .stroke(Color.borderPrimary, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Glassmorphism Overlay Style

struct GlassStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.overlayCornerRadius)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.overlayCornerRadius)
                    .stroke(Color.borderActive.opacity(0.3), lineWidth: 1)
            )
    }
}

extension View {
    func glassStyle() -> some View {
        modifier(GlassStyle())
    }
}

// MARK: - Icon Container

struct IconContainer: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.5))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - Selection Row Style

struct SelectionRowStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentPrimary.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM)
                    .stroke(isSelected ? Color.borderActive.opacity(0.2) : Color.clear, lineWidth: 1)
            )
    }
}

extension View {
    func selectionRowStyle(isSelected: Bool) -> some View {
        modifier(SelectionRowStyle(isSelected: isSelected))
    }
}

// MARK: - Radio Button

struct RadioButton: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.accentPrimary : Color.textTertiary, lineWidth: 2)
                .frame(width: AppConstants.UI.radioButtonSize, height: AppConstants.UI.radioButtonSize)

            if isSelected {
                Circle()
                    .fill(Color.accentPrimary)
                    .frame(width: AppConstants.UI.radioInnerSize, height: AppConstants.UI.radioInnerSize)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = .textTertiary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Download Indicator

struct DownloadIndicator: View {
    let isDownloaded: Bool

    var body: some View {
        if isDownloaded {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.successGreen)
        }
    }
}

// MARK: - Section Divider

struct SectionDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.borderPrimary)
    }
}

// MARK: - Pulse Animation

struct PulseRingModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .scaleEffect(scale)
                    .opacity(2 - scale)
                    .allowsHitTesting(false)
            )
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(.easeInOut(duration: AppConstants.Animation.pulseRingDuration).repeatForever(autoreverses: false)) {
                        scale = 1.3
                    }
                } else {
                    scale = 1.0
                }
            }
    }
}

extension View {
    func pulseRing(isActive: Bool, color: Color = .recordingRed) -> some View {
        modifier(PulseRingModifier(isActive: isActive, color: color))
    }
}

// MARK: - Spinning Modifier

struct SpinningModifier: ViewModifier {
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: AppConstants.Animation.spinnerDuration).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

extension View {
    func spinning() -> some View {
        modifier(SpinningModifier())
    }
}