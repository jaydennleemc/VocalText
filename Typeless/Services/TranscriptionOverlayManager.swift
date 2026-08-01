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

    /// Shared model — update properties, never replace rootView (keeps waveform state alive).
    private let model = OverlayModel()

    /// Capsule height is fixed; width grows with content (true pill / 胶囊).
    private let pillHeight: CGFloat = 28
    private let compactSize = CGSize(width: 140, height: 28)
    /// Success can grow wider; still one capsule (height fixed).
    private let resultMaxWidth: CGFloat = 280
    private let marginFromCursor: CGFloat = 14

    func showOverlay(transcriber: AudioTranscriber) {
        hideWorkItem?.cancel()
        hideWorkItem = nil

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
        .combineLatest(transcriber.$dictateFailure)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] state, failure in
            guard let self else { return }
            let (quick, recording, transcribing, text) = state
            let ready = NSLocalizedString("recording.state.ready", comment: "")

            if quick || recording {
                self.hideWorkItem?.cancel()
                self.hideWorkItem = nil
                self.model.phase = .listening
                self.model.text = ""
                self.model.volume = transcriber.volumeLevel
                self.resizeWindow(to: self.compactSize, reanchor: false)
                return
            }
            if transcribing {
                self.hideWorkItem?.cancel()
                self.hideWorkItem = nil
                self.model.phase = .transcribing
                self.model.text = ""
                self.model.volume = 0
                self.resizeWindow(to: self.compactSize, reanchor: false)
                return
            }
            // Failure first — never show error copy with a green check.
            if let failure, !failure.isEmpty {
                self.model.phase = .failed
                self.model.text = failure
                self.model.volume = 0
                self.resizeWindow(to: self.capsuleSize(for: failure), reanchor: false)
                self.scheduleHide(after: 2.0)
                return
            }
            if !text.isEmpty && text != ready {
                self.model.phase = .done
                self.model.text = text
                self.model.volume = 0
                self.resizeWindow(to: self.capsuleSize(for: text), reanchor: false)
                let seconds = min(3.2, max(1.6, Double(text.count) * 0.05))
                self.scheduleHide(after: seconds)
            } else {
                // Short cancel / quiet discard — no scary error toast.
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
                guard let self, self.model.phase == .listening else { return }
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
        let hosting = NSHostingController(rootView: OverlayRoot(model: model))
        hostingController = hosting

        // Hosting views default to an opaque chrome color — force true clear.
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.view.layer?.isOpaque = false
        if #available(macOS 13.0, *) {
            // Avoid solid fill under SwiftUI content.
            hosting.sizingOptions = []
        }

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: compactSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView?.layer?.isOpaque = false
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

    /// Always a fixed-height capsule; width fits a single line of text.
    private func capsuleSize(for text: String) -> CGSize {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let horizontalChrome: CGFloat = 34 // icon + padding
        let bounds = (trimmed as NSString).size(withAttributes: [.font: font])
        let width = min(
            resultMaxWidth,
            max(compactSize.width, ceil(bounds.width) + horizontalChrome)
        )
        return CGSize(width: width, height: pillHeight)
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
    case idle, listening, transcribing, done, failed
}

// MARK: - Root

private struct OverlayRoot: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        Group {
            switch model.phase {
            case .listening:
                DictatePill {
                    ListeningContent(level: model.volume)
                }
            case .transcribing:
                DictatePill {
                    TranscribingContent()
                }
            case .done:
                DictatePill {
                    ResultContent(text: model.text, style: .success)
                }
            case .failed:
                DictatePill {
                    ResultContent(text: model.text, style: .failure)
                }
            case .idle:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// MARK: - Shell (true capsule / 胶囊)

private struct DictatePill<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                // Capsule mask on vibrancy = elliptical ends at any height.
                VisualEffectCapsule(material: .hudWindow)
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.20), radius: 6, y: 2)
            .padding(2)
    }
}

/// Translucent HUD glass; corner radius follows height so ends stay fully round.
private struct VisualEffectCapsule: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> CapsuleEffectView {
        let view = CapsuleEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: CapsuleEffectView, context: Context) {
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.needsLayout = true
    }
}

private final class CapsuleEffectView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerCurve = .continuous
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        // True capsule: radius = half height → elliptical / 半圆端.
        layer?.cornerRadius = bounds.height / 2
    }
}

// MARK: - Listening

private struct ListeningContent: View {
    let level: Double

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 5, height: 5)
                .shadow(color: .red.opacity(0.5), radius: 2)

            CompactWaveform(level: level)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Live bars that span the pill width.
private struct CompactWaveform: View {
    let level: Double

    private let barCount = 22
    @State private var bars: [CGFloat] = Array(repeating: 0.14, count: 22)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 15.0 : 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                guard barCount > 0, size.width > 1, size.height > 1 else { return }

                let gap: CGFloat = 1.2
                let totalGap = gap * CGFloat(barCount - 1)
                let barWidth = max(1.2, (size.width - totalGap) / CGFloat(barCount))
                let step = barWidth + gap
                let midY = size.height / 2

                for i in 0..<barCount {
                    let h = max(2.5, bars[i] * size.height * 0.88)
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
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
                .tint(.secondary)

            Text(NSLocalizedString("overlay.transcribing", comment: "Transcribing…"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Result (success or failure)

private struct ResultContent: View {
    enum Style {
        case success, failure

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .failure: return .orange
            }
        }
    }

    let text: String
    let style: Style

    private var bodyText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Image(systemName: style.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(style.color)
                .symbolRenderingMode(.hierarchical)

            Text(bodyText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
