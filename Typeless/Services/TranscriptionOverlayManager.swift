//
//  TranscriptionOverlayManager.swift
//  Typeless
//
//  Created by LEEJAYMC on 23/5/2026.
//

import Cocoa
import SwiftUI
import Combine

/// Manages a floating overlay window that displays live transcription text
/// near the current text input cursor, similar to an input method candidate window.
@MainActor
final class TranscriptionOverlayManager {
    private var overlayWindow: NSWindow?
    private var hostingController: NSHostingController<OverlayView>?
    private var transcriptObserver: AnyCancellable?
    private var recordingObserver: AnyCancellable?

    // MARK: - Configuration

    private let windowWidth: CGFloat = 360
    private let windowHeight: CGFloat = 52
    private let windowPadding: CGFloat = 16
    private let cornerRadius: CGFloat = AppConstants.UI.radiusMD
    private let marginFromCursor: CGFloat = 24

    // MARK: - Show / Hide

    func showOverlay(transcriber: AudioTranscriber) {
        guard overlayWindow == nil else { return }

        let overlayView = OverlayView(transcript: transcriber.transcript)
        hostingController = NSHostingController(rootView: overlayView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = cornerRadius
        window.contentView?.layer?.masksToBounds = true

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = true

        positionWindow(window)
        window.orderFront(nil)
        overlayWindow = window

        transcriptObserver = transcriber.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTranscript in
                self?.updateTranscript(newTranscript)
            }

        recordingObserver = transcriber.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if !isRecording {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.hideOverlay()
                    }
                }
            }
    }

    func hideOverlay() {
        transcriptObserver = nil
        recordingObserver = nil
        overlayWindow?.orderOut(nil)
        overlayWindow?.contentViewController = nil
        overlayWindow = nil
        hostingController = nil
    }

    // MARK: - Positioning

    private func positionWindow(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let xPos = mouseLocation.x - windowWidth / 2
        let yPos = mouseLocation.y + marginFromCursor

        var adjustedX = xPos
        var adjustedY = yPos

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            let screenFrame = screen.visibleFrame
            if adjustedX < screenFrame.minX { adjustedX = screenFrame.minX + 8 }
            if adjustedX + windowWidth > screenFrame.maxX { adjustedX = screenFrame.maxX - windowWidth - 8 }
            if adjustedY + windowHeight > screenFrame.maxY { adjustedY = mouseLocation.y - windowHeight - marginFromCursor }
            if adjustedY < screenFrame.minY { adjustedY = screenFrame.minY + 8 }
        }

        window.setFrameOrigin(NSPoint(x: adjustedX, y: adjustedY))
    }

    // MARK: - Update Content

    private func updateTranscript(_ text: String) {
        guard let hostingController = hostingController else { return }
        let isEmpty = text == NSLocalizedString("recording.state.ready", comment: "") || text.isEmpty
        hostingController.rootView = OverlayView(transcript: isEmpty ? "..." : text)

        let hostingView = hostingController.view
        let fittingSize = hostingView.fittingSize
        let newHeight = max(windowHeight, fittingSize.height + windowPadding)
        let newWidth = max(windowWidth, min(fittingSize.width + windowPadding, 500))
        var frame = overlayWindow?.frame ?? .zero
        frame.size = NSSize(width: newWidth, height: newHeight)
        overlayWindow?.setFrame(frame, display: true, animate: true)
    }
}

// MARK: - Overlay View

private struct OverlayView: View {
    let transcript: String

    var body: some View {
        HStack(spacing: AppConstants.UI.spacingXS) {
            Image(systemName: "waveform")
                .font(.system(size: AppConstants.UI.iconSmall, weight: .medium))
                .foregroundColor(Color.accentPrimary)
                .symbolEffect(.pulse, isActive: true)

            Text(transcript)
                .font(.system(size: AppConstants.UI.fontBodyLarge))
                .foregroundColor(.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "command")
                .font(.system(size: AppConstants.UI.fontCaption, weight: .medium))
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, AppConstants.UI.spacingSM)
        .padding(.vertical, AppConstants.UI.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.radiusMD)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.radiusMD)
                .stroke(Color.borderActive, lineWidth: 1)
        )
        .padding(4)
    }
}