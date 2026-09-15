import AppKit
import SwiftUI
import VibeFlowCore

private enum Destination: String, CaseIterable, Identifiable {
    case home = "Home"
    case dictionary = "Dictionary"
    case snippets = "Snippets"
    case styles = "Styles"
    case transforms = "Transforms"
    case insights = "Insights"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "waveform"
        case .dictionary: "character.book.closed"
        case .snippets: "scissors"
        case .styles: "textformat"
        case .transforms: "wand.and.stars"
        case .insights: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var selection: Destination? = .home

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                BrandHeader()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)

                List(selection: $selection) {
                    Section("Workspace") {
                        ForEach(Destination.allCases.filter { $0 != .settings }) { destination in
                            Label(destination.rawValue, systemImage: destination.icon)
                                .tag(destination)
                        }
                    }
                    Section("System") {
                        Label(Destination.settings.rawValue, systemImage: Destination.settings.icon)
                            .tag(Destination.settings)
                    }
                }
                .listStyle(.sidebar)

                PrivacyBadge(store: model.store)
                    .padding(14)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } detail: {
            Group {
                switch selection ?? .home {
                case .home: HomeView(model: model)
                case .dictionary: DictionaryView(store: model.store)
                case .snippets: SnippetsView(store: model.store)
                case .styles: StylesView(store: model.store)
                case .transforms: TransformsView(model: model)
                case .insights: InsightsView(store: model.store)
                case .settings: SettingsView(model: model)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(Color(red: 0.48, green: 0.68, blue: 0.10))
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.73, green: 0.96, blue: 0.26))
                    .frame(width: 34, height: 34)
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("VibeFlow").font(.headline)
                Text("LOCAL DICTATION")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }
            Spacer()
        }
    }
}

private struct PrivacyBadge: View {
    @ObservedObject var store: LocalStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("LOCAL MODE", systemImage: "lock.fill")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.48, green: 0.68, blue: 0.10))
            Text("History \(store.retention == .never ? "off" : "on") · Context \(store.contextEnabled ? "on" : "off")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Audio is never saved")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct HomeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "SPEAK AT THE SPEED OF THOUGHT",
                    title: "Your voice, directly into your work.",
                    subtitle: "Hold the fn/Globe key anywhere on your Mac, or double-press it for hands-free dictation. VibeFlow transcribes locally and never submits."
                )

                HStack(spacing: 14) {
                    StatusCard(title: "Microphone", value: model.microphoneAuthorized ? "Ready" : "Needs access", icon: "mic.fill", ready: model.microphoneAuthorized)
                    StatusCard(title: "Whisper model", value: model.modelReady ? "base.en ready" : "Import model", icon: "cpu", ready: model.modelReady)
                    StatusCard(title: "Insertion", value: model.accessibilityAuthorized ? "Ready" : "Needs access", icon: "cursorarrow.click.2", ready: model.accessibilityAuthorized)
                }

                HStack(spacing: 16) {
                    Button {
                        model.toggleDictation()
                    } label: {
                        Label(model.phase == .listening ? "Stop dictation" : "Start dictation", systemImage: model.phase == .listening ? "stop.fill" : "mic.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.42, green: 0.61, blue: 0.08))

                    KeyCap(text: "fn", detail: "hold · double-press hands-free")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Last transcript", systemImage: "text.bubble")
                                .font(.headline)
                            Spacer()
                            Text(model.statusText).font(.caption).foregroundStyle(.secondary)
                        }
                        if model.lastTranscript.isEmpty {
                            Text("Your most recent result stays in memory until you quit. History is off by default.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                        } else {
                            Text(model.lastTranscript)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                        }
                        HStack {
                            Button("Copy") { model.copyLastTranscript() }.disabled(model.lastTranscript.isEmpty)
                            Button("Open in scratchpad") { model.putLastInScratchpad() }.disabled(model.lastTranscript.isEmpty)
                            Spacer()
                        }
                    }
                    .padding(8)
                }
            }
            .padding(34)
            .frame(maxWidth: 980, alignment: .leading)
        }
    }
}

private struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let ready: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Spacer()
                Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(ready ? .green : .orange)
                    .accessibilityLabel(ready ? "Ready" : "Needs attention")
            }
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .semibold)).lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.separator.opacity(0.45)))
    }
}

private struct KeyCap: View {
    let text: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(text).font(.system(size: 13, weight: .bold, design: .monospaced))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct DictionaryView: View {
    @ObservedObject var store: LocalStore
    @State private var spoken = ""
    @State private var written = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(eyebrow: "PERSONAL VOCABULARY", title: "Dictionary", subtitle: "Teach exact spellings and map common mishearings. Everything stays on this Mac.")
            HStack {
                TextField("What you say — e.g. super base", text: $spoken)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                TextField("Exact output — e.g. Supabase", text: $written)
                Button("Add") {
                    store.addDictionary(spoken: spoken, written: written)
                    spoken = ""
                    written = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(spoken.trimmingCharacters(in: .whitespaces).isEmpty || written.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))

            List {
                ForEach(store.dictionary) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.writtenForm).font(.headline)
                            Text("Say “\(entry.spokenForm)”").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.deleteDictionary(ids: [entry.id])
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete \(entry.writtenForm)")
                    }
                    .padding(.vertical, 5)
                }
            }
            .listStyle(.inset)
        }
        .padding(34)
    }
}

private struct SnippetsView: View {
    @ObservedObject var store: LocalStore
    @State private var name = ""
    @State private var trigger = ""
    @State private var expansion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(eyebrow: "VOICE SHORTCUTS", title: "Snippets", subtitle: "Say a whole trigger phrase to expand text you use repeatedly.")
            VStack(spacing: 10) {
                HStack {
                    TextField("Name", text: $name)
                    TextField("Spoken trigger", text: $trigger)
                }
                TextField("Expansion", text: $expansion, axis: .vertical)
                    .lineLimit(2...5)
                HStack {
                    Spacer()
                    Button("Add snippet") {
                        store.addSnippet(name: name, trigger: trigger, expansion: expansion)
                        name = ""; trigger = ""; expansion = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || trigger.isEmpty || expansion.isEmpty)
                }
            }
            .padding(16)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))

            List {
                ForEach(store.snippets) { snippet in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snippet.name).font(.headline)
                            Text("Say “\(snippet.trigger)”").font(.caption).foregroundStyle(.secondary)
                            Text(snippet.expansion).lineLimit(2).font(.callout)
                        }
                        Spacer()
                        Button(role: .destructive) { store.deleteSnippets(ids: [snippet.id]) } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain)
                    }
                    .padding(.vertical, 5)
                }
            }
            .listStyle(.inset)
        }
        .padding(34)
    }
}

private struct StylesView: View {
    @ObservedObject var store: LocalStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(eyebrow: "HOW YOUR WORDS LAND", title: "Styles", subtitle: "The first release keeps automatic rewriting conservative and deterministic.")

                SettingCard(icon: "chevron.left.forwardslash.chevron.right", title: "Code & prompts", description: "Preserve Markdown and translate spoken developer notation such as dot env, dash dash force, and casing commands.") {
                    Toggle("Developer formatting", isOn: $store.developerMode)
                }

                SettingCard(icon: "terminal", title: "Terminal safety", description: "VibeFlow inserts text only. It never synthesizes Return or executes the command.") {
                    Label("Always on", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                }

                SettingCard(icon: "text.alignleft", title: "Clean dictation", description: "Remove obvious filler and repetition, normalize punctuation, and preserve uncertainty and intent.") {
                    Text("Conservative").foregroundStyle(.secondary)
                }
            }
            .padding(34)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

private struct TransformsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(eyebrow: "LOCAL TRANSFORMS", title: "Shape the thought, not the meaning.", subtitle: "Prompt Builder organizes text locally. It does not answer the prompt or add requirements.")

            HStack(spacing: 14) {
                TransformCard(icon: "wand.and.stars", title: "Polish", description: "Run conservative cleanup again and open the result in the scratchpad.") {
                    model.putLastInScratchpad()
                }
                TransformCard(icon: "curlybraces.square", title: "Prompt Builder", description: "Place the dictated request under a clear Objective heading for further editing.") {
                    model.makePromptFromLast()
                }
            }

            GroupBox("Scratchpad — local only") {
                TextEditor(text: $model.scratchpad)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 280)
                    .padding(8)
            }
        }
        .padding(34)
    }
}

private struct TransformCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title2)
            Text(title).font(.headline)
            Text(description).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Use last transcript", action: action)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.separator.opacity(0.45)))
    }
}

private struct InsightsView: View {
    @ObservedObject var store: LocalStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(eyebrow: "ON-DEVICE COUNTERS", title: "Insights", subtitle: "Only totals and timings are stored. No transcript content is needed for these metrics.")
                HStack(spacing: 14) {
                    MetricCard(value: "\(store.metrics.wordsPerMinute)", label: "WORDS PER MINUTE", icon: "speedometer")
                    MetricCard(value: "\(store.metrics.fixes)", label: "LOCAL FIXES", icon: "wand.and.rays")
                    MetricCard(value: "\(store.metrics.totalWords)", label: "WORDS DICTATED", icon: "text.word.spacing")
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Privacy-respecting by design").font(.headline)
                        Text("VibeFlow records aggregate counts, not app titles, document names, audio, or dictated text when History is off.")
                            .foregroundStyle(.secondary)
                        Button("Reset metrics", role: .destructive) { store.resetMetrics() }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(34)
            .frame(maxWidth: 980, alignment: .leading)
        }
    }
}

private struct MetricCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(Color(red: 0.48, green: 0.68, blue: 0.10))
            Text(value).font(.system(size: 34, weight: .semibold, design: .rounded))
            Text(label).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).tracking(0.8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.separator.opacity(0.45)))
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var store: LocalStore
    @State private var confirmDelete = false

    init(model: AppModel) {
        self.model = model
        store = model.store
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(eyebrow: "CONTROL THE BOUNDARY", title: "Settings", subtitle: "Microphone → this Mac → your cursor. No account and no cloud transcription.")

                SettingCard(icon: "keyboard", title: "Fn key dictation", description: "Hold fn and release to insert. Double-press fn to keep listening hands-free; press fn once more to stop.") {
                    Text("fn")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }

                SettingCard(icon: "cpu", title: "Whisper model", description: model.modelURL?.lastPathComponent ?? "No local model found") {
                    Button("Import .bin…") { model.importModel() }
                }

                SettingCard(icon: "cursorarrow.click.2", title: "Accessibility", description: model.accessibilityAuthorized ? "Granted. VibeFlow can insert at your cursor." : "Required only for inserting into other apps.") {
                    Button(model.accessibilityAuthorized ? "Granted" : "Grant access") { model.requestAccessibility() }
                        .disabled(model.accessibilityAuthorized)
                }

                SettingCard(icon: "clock.arrow.circlepath", title: "Transcript history", description: "Audio is never retained. Transcript history is stored only when you choose a duration.") {
                    Picker("Retention", selection: $store.retention) {
                        ForEach(HistoryRetention.allCases) { value in Text(value.title).tag(value) }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                SettingCard(icon: "scope", title: "Nearby text context", description: "Off by default. The current build never captures screenshots or full documents.") {
                    Toggle("Context", isOn: $store.contextEnabled)
                }

                SettingCard(icon: "trash", title: "Local data", description: "Remove saved transcript history and aggregate counters. Dictionary and snippets remain.") {
                    Button("Clear history & metrics", role: .destructive) { confirmDelete = true }
                }
            }
            .padding(34)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .confirmationDialog("Clear local history and metrics?", isPresented: $confirmDelete) {
            Button("Clear history and metrics", role: .destructive) {
                store.clearHistory()
                store.resetMetrics()
            }
        } message: {
            Text("This removes saved transcript text and aggregate usage counters. It cannot be undone.")
        }
    }
}

private struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.48, green: 0.68, blue: 0.10))
                .tracking(1.4)
            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }
}

private struct SettingCard<Accessory: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(Color(red: 0.48, green: 0.68, blue: 0.10))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 24)
            accessory()
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator.opacity(0.45)))
    }
}
