//
//  ErrorBannerView.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

// MARK: - Error Banner View

struct ErrorBanner: View {
    let message: String
    let type: ErrorType
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: AppConstants.UI.spacingSM) {
            Image(systemName: type.icon)
                .font(.system(size: AppConstants.UI.iconMedium))
                .foregroundColor(type.color)
                .frame(width: 24, height: 24)

            Text(message)
                .font(.system(size: AppConstants.UI.fontBodyLarge))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
            .background(Color.bgHover)
            .clipShape(Circle())
        }
        .padding(.vertical, AppConstants.UI.spacingSM)
        .padding(.horizontal, AppConstants.UI.spacingMD)
        .background(type.backgroundColor)
        .cornerRadius(AppConstants.UI.radiusSM)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.radiusSM)
                .stroke(type.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, AppConstants.UI.spacingSM)
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            )
        )
    }
}
