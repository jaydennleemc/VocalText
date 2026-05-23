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
    private let cornerRadius: CGFloat = 10
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

        // Make it float above all apps, like an input method window
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = true

        // Position near cursor
        positionWindow(window)

        window.orderFront(nil)
        overlayWindow = window

        // Observe transcript changes
        transcriptObserver = transcriber.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTranscript in
                self?.updateTranscript(newTranscript)
            }

        // Observe recording state to auto-hide
        recordingObserver = transcriber.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if !isRecording {
                    // Delay hide to show final transcription briefly
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
        // Position above the cursor, centered horizontally
        let xPos = mouseLocation.x - windowWidth / 2
        let yPos = mouseLocation.y + marginFromCursor

        // Ensure the window stays within screen bounds
        var adjustedX = xPos
        var adjustedY = yPos

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            let screenFrame = screen.visibleFrame
            if adjustedX < screenFrame.minX {
                adjustedX = screenFrame.minX + 8
            }
            if adjustedX + windowWidth > screenFrame.maxX {
                adjustedX = screenFrame.maxX - windowWidth - 8
            }
            if adjustedY + windowHeight > screenFrame.maxY {
                adjustedY = mouseLocation.y - windowHeight - marginFromCursor
            }
            if adjustedY < screenFrame.minY {
                adjustedY = screenFrame.minY + 8
            }
        }

        window.setFrameOrigin(NSPoint(x: adjustedX, y: adjustedY))
    }

    // MARK: - Update Content

    private func updateTranscript(_ text: String) {
        guard let hostingController = hostingController else { return }
        let isEmpty = text == NSLocalizedString("recording.state.ready", comment: "") ||
                      text.isEmpty
        hostingController.rootView = OverlayView(transcript: isEmpty ? "..." : text)

        // Resize window to fit content
        let hostingView = hostingController.view
        let fittingSize = hostingView.fittingSize
        let newHeight = max(windowHeight, fittingSize.height + windowPadding)
        let newWidth = max(windowWidth, min(fittingSize.width + windowPadding, 500))
        var frame = overlayWindow?.frame ?? .zero
        frame.size = NSSize(width: newWidth, height: newHeight)
        // Keep the bottom-left corner fixed
        overlayWindow?.setFrame(frame, display: true, animate: true)
    }
}

// MARK: - Overlay View

private struct OverlayView: View {
    let transcript: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentColor)
                .symbolEffect(.pulse, isActive: true)

            Text(transcript)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "command")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .padding(4)
    }
}