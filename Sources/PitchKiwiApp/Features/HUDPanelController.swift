import AppKit
import Combine
import SwiftUI
import PitchKiwiCore

@MainActor
final class HUDPanelController {
    private let panel: NSPanel
    private var cancellable: AnyCancellable?

    init(model: AppModel) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 168, height: 42),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: HUDView(model: model))

        cancellable = model.$phase.sink { [weak self] phase in
            guard let self else { return }
            if phase == .idle {
                self.panel.orderOut(nil)
            } else {
                self.positionOnActiveScreen()
                self.panel.orderFrontRegardless()
            }
        }
    }

    private func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: visible.midX - panel.frame.width / 2,
            y: visible.minY + 42
        )
        panel.setFrameOrigin(origin)
    }
}

private struct HUDView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.phase == .listening {
                HStack(spacing: 9) {
                    Text("🥝")
                        .font(.system(size: 12))
                    LiveWaveform(level: model.audioLevel)
                    Spacer(minLength: 0)
                    if model.handsFreeMode {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                            Text("LOCK")
                        }
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 0.12))
                        .accessibilityLabel("Hands-free capture locked")
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Hold Fn to capture")
                    }
                }
            } else {
                HStack(spacing: 9) {
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(iconColor)
                    Text(model.statusText)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 168, height: 42)
        .tinyLiquidGlass()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.phase == .listening ? "Listening. \(detail)" : model.statusText)
    }

    private var iconName: String {
        switch model.phase {
        case .listening: "waveform"
        case .transcribing: "cpu"
        case .refining: "wand.and.stars"
        case .inserting: "arrow.down.doc"
        case .result: "checkmark"
        case .error: "exclamationmark.triangle"
        case .cancelling: "xmark"
        case .idle: "waveform"
        }
    }

    private var iconColor: Color {
        switch model.phase {
        case .listening: Color(red: 0.58, green: 0.78, blue: 0.12)
        case .error: Color(red: 0.94, green: 0.42, blue: 0.42)
        default: Color(red: 0.58, green: 0.78, blue: 0.12)
        }
    }

    private var detail: String {
        switch model.phase {
        case .listening: model.handsFreeMode ? "Press fn once to stop" : "Release fn to insert · double-press for hands-free"
        case .transcribing, .refining: "Nothing leaves this Mac"
        case .inserting: "Never submits or presses Return"
        case .result: model.lastTranscript.isEmpty ? "Done" : "Saved as last transcript"
        case .error: "Open PitchKiwi for recovery"
        case .cancelling: "Discarding audio"
        case .idle: "Local and ready"
        }
    }
}

private struct LiveWaveform: View {
    let level: Float
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recentLevels: [CGFloat] = Array(repeating: 0.06, count: 7)

    private let weights: [CGFloat] = [0.68, 0.88, 1, 0.76, 0.94, 0.82, 0.64]

    var body: some View {
        Group {
            if reduceMotion {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.58, green: 0.78, blue: 0.12).opacity(level > 0.03 ? 1 : 0.45))
                    .frame(width: 48, height: 28)
            } else {
                HStack(spacing: 3) {
                    ForEach(weights.indices, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.58, green: 0.78, blue: 0.12).opacity(0.92))
                            .frame(width: 3, height: barHeight(at: index))
                    }
                }
                .frame(width: 48, height: 28)
            }
        }
        .onChange(of: level) { _, newLevel in
            let next = CGFloat(min(1, max(0.04, newLevel)))
            recentLevels.removeFirst()
            recentLevels.append(next)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.06), value: recentLevels)
        .accessibilityHidden(true)
    }

    private func barHeight(at index: Int) -> CGFloat {
        3 + (recentLevels[index] * 22 * weights[index])
    }
}

private extension View {
    @ViewBuilder
    func tinyLiquidGlass() -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            glassEffect(.regular.tint(.black.opacity(0.08)), in: .capsule)
        } else {
            background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.18)))
        }
#else
        background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.18)))
#endif
    }
}
