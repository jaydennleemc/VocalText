import SwiftUI

// MARK: - Typeless Theme Colors

extension Color {
    // MARK: - Backgrounds

    static let bgPrimary = Color(red: 0.059, green: 0.059, blue: 0.067)       // #0f0f11
    static let bgSecondary = Color(red: 0.102, green: 0.102, blue: 0.118)     // #1a1a1e
    static let bgCard = Color(red: 0.133, green: 0.133, blue: 0.149)          // #222226
    static let bgHover = Color(red: 0.165, green: 0.165, blue: 0.184)        // #2a2a2f

    // MARK: - Borders

    static let borderPrimary = Color(red: 0.180, green: 0.180, blue: 0.204)   // #2e2e34
    static let borderActive = Color(red: 0.369, green: 0.361, blue: 0.902)    // #5e5ce6

    // MARK: - Text

    static let textPrimary = Color(red: 0.961, green: 0.961, blue: 0.969)     // #f5f5f7
    static let textSecondary = Color(red: 0.596, green: 0.596, blue: 0.624)   // #98989f
    static let textTertiary = Color(red: 0.388, green: 0.388, blue: 0.420)    // #63636b

    // MARK: - Accent

    static let accentPrimary = Color(red: 0.369, green: 0.361, blue: 0.902)   // #5e5ce6
    static let accentHover = Color(red: 0.420, green: 0.412, blue: 0.941)     // #6b69f0
    static let accentGlow = Color(red: 0.369, green: 0.361, blue: 0.902).opacity(0.3)

    // MARK: - Semantic

    static let recordingRed = Color(red: 1.0, green: 0.271, blue: 0.227)      // #ff453a
    static let recordingGlow = Color(red: 1.0, green: 0.271, blue: 0.227).opacity(0.3)
    static let successGreen = Color(red: 0.188, green: 0.820, blue: 0.345)    // #30d158
    static let warningOrange = Color(red: 1.0, green: 0.624, blue: 0.039)     // #ff9f0a
    static let accentPurple = Color(red: 0.749, green: 0.353, blue: 0.949)    // #bf5af2

    // MARK: - Gradients

    static let accentGradient = LinearGradient(
        colors: [.accentPrimary, .accentPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let recordingGradient = LinearGradient(
        colors: [.recordingRed, Color(red: 1.0, green: 0.420, blue: 0.353)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let tutorialGradient = LinearGradient(
        colors: [.accentPrimary, .accentPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Shape Styles

extension ShapeStyle where Self == LinearGradient {
    static var accentGradient: LinearGradient { Color.accentGradient }
    static var recordingGradient: LinearGradient { Color.recordingGradient }
    static var tutorialGradient: LinearGradient { Color.tutorialGradient }
}