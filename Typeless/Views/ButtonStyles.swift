//
//  ButtonStyles.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppConstants.UI.spacingMD)
            .padding(.vertical, AppConstants.UI.spacingXS)
            .background(Color.accentGradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: AppConstants.Animation.buttonPressDuration), value: configuration.isPressed)
    }
}

// MARK: - Settings Primary Button Style

struct SettingsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppConstants.UI.spacingSM)
            .padding(.vertical, 6)
            .background(Color.accentGradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: AppConstants.Animation.buttonPressDuration), value: configuration.isPressed)
    }
}

// MARK: - Settings Secondary Button Style

struct SettingsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppConstants.UI.spacingSM)
            .padding(.vertical, 6)
            .background(Color.bgHover)
            .foregroundColor(.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: AppConstants.Animation.buttonPressDuration), value: configuration.isPressed)
    }
}
