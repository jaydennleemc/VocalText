//
//  TranscriptionCardView.swift
//  Typeless
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

// MARK: - Transcription Card

struct TranscriptionCard: View {
    let text: String
    let isEmpty: Bool
    let onCopy: () -> Void

    @State private var showCopiedIndicator = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(isEmpty ? NSLocalizedString("recording.state.ready", comment: "Ready to record") : text)
                    .font(.system(size: AppConstants.UI.fontBodyLarge))
                    .lineSpacing(4)
                    .foregroundColor(isEmpty ? .textTertiary : .textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppConstants.UI.spacingSM)
            }
            .frame(maxHeight: AppConstants.UI.transcriptMaxHeight)

            SectionDivider()

            // Footer with copy button
            HStack {
                Spacer()

                if showCopiedIndicator {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                        Text("main.view.copied")
                            .font(.system(size: AppConstants.UI.fontCaption, weight: .medium))
                    }
                    .foregroundColor(.successGreen)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else if !isEmpty {
                    Button(action: {
                        onCopy()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopiedIndicator = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animation.copiedIndicatorDuration) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopiedIndicator = false
                            }
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: AppConstants.UI.iconSmall))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(NSLocalizedString("main.view.copy.tooltip", comment: "Copy to clipboard"))
                }
            }
            .padding(.horizontal, AppConstants.UI.spacingSM)
            .padding(.vertical, AppConstants.UI.spacingXS)
            .background(Color.bgHover.opacity(0.5))
        }
        .cardStyle()
    }
}

// MARK: - Transcription State View

struct TranscriptionStateView: View {
    let transcript: String
    let isEmpty: Bool
    let onCopy: () -> Void

    @State private var showCopiedIndicator = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(isEmpty ? NSLocalizedString("recording.state.ready", comment: "Ready to record") : transcript)
                    .font(.system(size: AppConstants.UI.fontBodyLarge))
                    .lineSpacing(4)
                    .foregroundColor(isEmpty ? .textTertiary : .textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppConstants.UI.spacingSM)
                    .padding(.vertical, AppConstants.UI.spacingXS)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, AppConstants.UI.spacingMD)
        .padding(.vertical, AppConstants.UI.spacingXS)
    }
}
