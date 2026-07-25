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
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 18))
                .foregroundColor(type.color)
                .frame(width: 24, height: 24)

            Text(message)
                .font(.system(size: 14))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(Circle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(type.backgroundColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(type.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            )
        )
    }
}