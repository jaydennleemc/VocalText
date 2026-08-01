//
//  TranscriptionOverlayManager.swift
//  Typeless
//
//  Quick-dictate HUD: compact waveform pill near the cursor.
//  listening → full-width live bars · transcribing → spinner · done → full result text
//

import Cocoa
import SwiftUI
import Combine

@MainActor
final class TranscriptionOverlayManager {
    private var overlayWindow: NSWindow?
    private var hostingController: NSHostingController<OverlayRoot>?
    private var cancellables = Set<AnyCancellable>()
    private var hideWorkItem: DispatchWorkItem?
    private var currentPhase: OverlayPhase = .idle

    /// Shared model — update properties, never replace rootView (keeps waveform state alive).
    private let model = OverlayModel()

    /// Compact pill while listening / transcribing.
    private let compactSize = CGSize(width: 220, height: 44)
    /// Expanded bubble for full transcript preview.
    private let resultMaxSize = CGSize(width: 320, height: 160)
    private let marginFromCursor: CGFloat = 22

    func showOverlay(transcriber: AudioTranscriber) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        currentPhase = .listening

        model.phase = .listening
        model.text = ""
        model.volume = 0

        if overlayWindow == nil {
            installWindow()
        } else if let window = overlayWindow {
            resizeWindow(to: compactSize, reanchor: true)
            window.orderFront(nil)
        }

        cancellables.removeAll()

        Publishers.CombineLatest4(
            transcriber.$isQuickRecording,
            transcriber.$isRecording,
            transcriber.$isTranscribing,
            transcriber.$transcript
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] quick, recording, transcribing, text in
            guard let self else { return }
            let ready = NSLocalizedString("recording.state.ready", comment: "")

            if quick || recording {
                self.hideWorkItem?.cancel()
                self.hideWorkItem = nil
                self.currentPhase = .listening
                self.model.phase = .listening
                self.model.text = ""
                self.model.volume = transcriber.volumeLevel
                self.resizeWindow(to: self.compactSize, reanchor: false)
                return
            }
            if transcribing {
                self.hideWorkItem?.cancel()
                self.hideWorkItem = nil
                self.currentPhase = .transcribing
                self.model.phase = .transcribing
                self.model.text = ""
                self.model.volume = 0
                self.resizeWindow(to: self.compactSize, reanchor: false)
                return
            }
            if !text.isEmpty && text != ready {
                self.currentPhase = .done
                self.model.phase = .done
                self.model.text = text
                self.model.volume = 0
                self.resizeWindow(to: self.resultSize(for: text), reanchor: false)
                // Longer hide so user can read the full result.
                let seconds = min(4.0, max(2.0, Double(text.count) * 0.06))
                self.scheduleHide(after: seconds)
            } else {
                self.currentPhase = .idle
                self.model.phase = .idle
                self.model.text = ""
                self.model.volume = 0
                self.scheduleHide(after: 0.35)
            }
        }
        .store(in: &cancellables)

        // Volume only mutates the model — does NOT rebuild the hosting tree.
        transcriber.$volumeLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volume in
                guard let self, self.currentPhase == .listening else { return }
                self.model.volume = volume
            }
            .store(in: &cancellables)
    }

    func hideOverlay() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        cancellables.removeAll()
        overlayWindow?.orderOut(nil)
        overlayWindow?.contentViewController = nil
        overlayWindow = nil
        hostingController = nil
        currentPhase = .idle
        model.phase = .idle
        model.volume = 0
        model.text = ""
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hideOverlay() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func installWindow() {
        hostingController = NSHostingController(rootView: OverlayRoot(model: model))

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: compactSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.masksToBounds = false
        window.setContentSize(compactSize)
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = true

        positionOnce(window, size: compactSize)
        window.orderFront(nil)
        overlayWindow = window
    }

    private func resultSize(for text: String) -> CGSize {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let maxTextWidth = resultMaxSize.width - 48 // padding + icon
        let bounds = (trimmed as NSString).boundingRect(
            with: NSSize(width: maxTextWidth, height: resultMaxSize.height - 28),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let width = min(resultMaxSize.width, max(compactSize.width, ceil(bounds.width) + 56))
        let height = min(resultMaxSize.height, max(compactSize.height, ceil(bounds.height) + 28))
        return CGSize(width: width, height: height)
    }

    private func resizeWindow(to size: CGSize, reanchor: Bool) {
        guard let window = overlayWindow else { return }
        let current = window.frame.size
        if abs(current.width - size.width) < 0.5, abs(current.height - size.height) < 0.5 {
            if reanchor { positionOnce(window, size: size) }
            return
        }
        // Keep top-center anchored so growth expands downward / sideways evenly.
        let frame = window.frame
        let midX = frame.midX
        let topY = frame.maxY
        var x = midX - size.width / 2
        var y = topY - size.height
        if let screen = window.screen ?? NSScreen.main {
            let f = screen.visibleFrame
            x = min(max(x, f.minX + 10), f.maxX - size.width - 10)
            y = min(max(y, f.minY + 10), f.maxY - size.height - 10)
        }
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true, animate: false)
        window.contentViewController?.view.frame = NSRect(origin: .zero, size: size)
    }

    private func positionOnce(_ window: NSWindow, size: CGSize) {
        let mouse = NSEvent.mouseLocation
        var x = mouse.x - size.width / 2
        var y = mouse.y + marginFromCursor
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            let f = screen.visibleFrame
            x = min(max(x, f.minX + 10), f.maxX - size.width - 10)
            if y + size.height > f.maxY {
                y = mouse.y - size.height - marginFromCursor
            }
            y = max(y, f.minY + 10)
        }
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: false, animate: false)
    }
}

// MARK: - Model

@MainActor
private final class OverlayModel: ObservableObject {
    @Published var phase: OverlayPhase = .idle
    @Published var text: String = ""
    @Published var volume: Double = 0
}

private enum OverlayPhase: Equatable {
    case idle, listening, transcribing, done
}

// MARK: - Root

private struct OverlayRoot: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        Group {
            switch model.phase {
            case .listening:
                DictatePill(corner: 20) {
                    ListeningContent(level: model.volume)
                }
            case .transcribing:
                DictatePill(corner: 20) {
                    TranscribingContent()
                }
            case .done:
                DictatePill(corner: 16) {
                    DoneContent(text: model.text)
                }
            case .idle:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shell

private struct DictatePill<Content: View>: View {
    var corner: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .padding(4)
    }
}

// MARK: - Listening

private struct ListeningContent: View {
    let level: Double

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
                .shadow(color: .red.opacity(0.55), radius: 3)

            CompactWaveform(level: level)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Live bars that always span the full available width.
private struct CompactWaveform: View {
    let level: Double

    private let barCount = 36
    @State private var bars: [CGFloat] = Array(repeating: 0.14, count: 36)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 15.0 : 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                guard barCount > 0, size.width > 1, size.height > 1 else { return }

                // Fill entire width: compute bar width + gap so bars reach the right edge.
                let gap: CGFloat = 1.5
                let totalGap = gap * CGFloat(barCount - 1)
                let barWidth = max(1.5, (size.width - totalGap) / CGFloat(barCount))
                let step = barWidth + gap
                let midY = size.height / 2

                for i in 0..<barCount {
                    let h = max(3, bars[i] * size.height * 0.92)
                    let x = CGFloat(i) * step
                    let rect = CGRect(x: x, y: midY - h / 2, width: barWidth, height: h)
                    let alpha = 0.40 + Double(bars[i]) * 0.60
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(Color.red.opacity(alpha))
                    )
                }
            }
            .onChange(of: timeline.date) { _ in
                tick(level: level)
            }
        }
        .onChange(of: level) { newValue in
            let amp = displayAmp(newValue)
            if !bars.isEmpty {
                bars[bars.count - 1] = max(bars[bars.count - 1], amp)
            }
        }
        .onAppear {
            if bars.count != barCount {
                bars = Array(repeating: 0.14, count: barCount)
            }
        }
    }

    private func displayAmp(_ raw: Double) -> CGFloat {
        let boosted = min(1.0, pow(max(0, raw), 0.55) * 1.35)
        return CGFloat(boosted)
    }

    private func tick(level: Double) {
        let amp = displayAmp(level)
        var next = bars
        next.removeFirst()
        let jitter = CGFloat.random(in: 0.85...1.0)
        next.append(max(0.12, amp * jitter))
        if next.count >= 2 {
            let i = next.count - 2
            next[i] = next[i] * 0.35 + next[i + 1] * 0.65
        }
        bars = next
    }
}

// MARK: - Transcribing

private struct TranscribingContent: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(.secondary)

            Text(NSLocalizedString("overlay.transcribing", comment: "Transcribing…"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Done (full transcript, multi-line)

private struct DoneContent: View {
    let text: String

    private var bodyText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)
                .padding(.top, 1)

            Text(bodyText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
