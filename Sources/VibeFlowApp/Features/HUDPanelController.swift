import AppKit
import Combine
import SwiftUI
import VibeFlowCore

@MainActor
final class HUDPanelController {
    private let panel: NSPanel
    private var cancellable: AnyCancellable?

    init(model: AppModel) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 310, height: 68),
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(iconColor.opacity(0.18)).frame(width: 42, height: 42)
                Image(systemName: iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating, isActive: model.phase.isActive)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(model.statusText)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if model.phase == .listening {
                Text("ESC")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 310, height: 68)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.statusText)
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
        case .listening: Color(red: 0.35, green: 0.83, blue: 0.72)
        case .error: Color(red: 0.94, green: 0.42, blue: 0.42)
        default: Color(red: 0.66, green: 0.65, blue: 1)
        }
    }

    private var detail: String {
        switch model.phase {
        case .listening: model.handsFreeMode ? "Press fn once to stop" : "Release fn to insert · double-press for hands-free"
        case .transcribing, .refining: "Nothing leaves this Mac"
        case .inserting: "Never submits or presses Return"
        case .result: model.lastTranscript.isEmpty ? "Done" : "Saved as last transcript"
        case .error: "Open VibeFlow for recovery"
        case .cancelling: "Discarding audio"
        case .idle: "Local and ready"
        }
    }
}
