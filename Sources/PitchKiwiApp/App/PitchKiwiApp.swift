import AppKit
import SwiftUI
import PitchKiwiCore

@main
struct PitchKiwiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup("PitchKiwi", id: "main") {
            MainView(model: model)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1_080, height: 720)
        .commands {
            CommandMenu("Dictation") {
                Button(model.phase == .listening ? "Stop Dictation" : "Start Dictation") {
                    model.toggleDictation()
                }

                Button("Cancel Dictation") { model.cancelDictation() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!model.phase.isActive)

                Divider()

                Button("Copy Last Transcript") { model.copyLastTranscript() }
                    .disabled(model.lastTranscript.isEmpty)
            }
        }

        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Text("🥝")
                .accessibilityLabel(model.phase == .listening ? "PitchKiwi is listening" : "PitchKiwi")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hudController: HUDPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let model = AppModel.shared
        hudController = HUDPanelController(model: model)
        model.shortcutMonitor.start()
        model.refreshPermissions()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppModel.shared.refreshPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.shortcutMonitor.stop()
        AppModel.shared.cancelDictation()
    }
}

private struct MenuBarContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button(model.phase == .listening ? "Stop Dictation" : "Start Dictation") {
            model.toggleDictation()
        }
        Text(model.handsFreeMode ? "Hands-free • press fn to stop" : "Hold fn • double-press for hands-free")
        Text("Mode: \(model.store.dictationMode.title)")
        if model.store.dictationMode == .prompt {
            Text("Prompt length: \(model.store.promptLength.title)")
        }
        Divider()
        Button("Copy Last Transcript") { model.copyLastTranscript() }
            .disabled(model.lastTranscript.isEmpty)
        Button("Open PitchKiwi") { model.showMainWindow() }
        Divider()
        Text("Local • History \(model.store.retention == .never ? "off" : "on") • Context \(model.store.contextEnabled ? "on" : "off")")
        Divider()
        Button("Quit PitchKiwi") { NSApp.terminate(nil) }
    }
}
