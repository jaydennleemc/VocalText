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
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundColor(isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 120)

            Divider().overlay(Color(nsColor: .separatorColor))

            // Footer with copy button
            HStack {
                Spacer()

                if showCopiedIndicator {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                        Text("Copied")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.green)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else if !isEmpty {
                    Button(action: {
                        onCopy()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopiedIndicator = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopiedIndicator = false
                            }
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(NSLocalizedString("main.view.copy.tooltip", comment: "Copy to clipboard"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}