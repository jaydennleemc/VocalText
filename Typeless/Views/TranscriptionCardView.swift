//
//  TranscriptionCardView.swift
//  Typeless
//

import SwiftUI

// MARK: - Transcription Card

struct TranscriptionCard: View {
    let text: String
    let isEmpty: Bool
    let onCopy: () -> Void

    @State private var showCopied = false

    private var displayText: String {
        isEmpty
            ? NSLocalizedString("recording.state.ready", comment: "Ready to record")
            : text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                Text(displayText)
                    .font(.system(size: 14))
                    .lineSpacing(5)
                    .foregroundStyle(isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(14)
            }
            .frame(maxHeight: 160)

            if !isEmpty {
                Divider().opacity(0.4)

                HStack {
                    Spacer()
                    if showCopied {
                        Label("Copied", systemImage: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Button {
                            onCopy()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showCopied = false
                                }
                            }
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .help(NSLocalizedString("main.view.copy.tooltip", comment: "Copy to clipboard"))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.35))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.45), lineWidth: 1)
        }
    }
}
