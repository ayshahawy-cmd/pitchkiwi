import AppKit
import SwiftUI
import PitchKiwiCore

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
    @AppStorage("pitchKiwiOnboardingCompletedV1") private var onboardingCompleted = false
    @State private var selection: Destination? = .home
    @State private var showOnboarding = false

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
            ZStack {
                KiwiBackdrop()
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
            }
        }
        .tint(KiwiPalette.accent)
        .task {
            if !onboardingCompleted {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(model: model) {
                onboardingCompleted = true
                showOnboarding = false
            }
            .interactiveDismissDisabled()
        }
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: AppModel
    let onComplete: () -> Void
    @State private var step = 0

    private let steps = 4

    var body: some View {
        ZStack {
            KiwiBackdrop()

            VStack(spacing: 0) {
                HStack {
                    BrandHeader()
                        .frame(width: 180)
                    Spacer()
                    HStack(spacing: 7) {
                        ForEach(0..<steps, id: \.self) { index in
                            Capsule(style: .continuous)
                                .fill(index == step ? KiwiPalette.accent : Color.primary.opacity(0.12))
                                .frame(width: index == step ? 26 : 8, height: 8)
                                .animation(.snappy(duration: 0.24), value: step)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 26)

                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: controlsStep
                    case 2: permissionsStep
                    default: readyStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())

                HStack {
                    if step > 0 {
                        Button("Back") {
                            withAnimation(.snappy) { step -= 1 }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button(step == steps - 1 ? "Start using PitchKiwi" : "Continue") {
                        if step == steps - 1 {
                            onComplete()
                        } else {
                            withAnimation(.snappy) { step += 1 }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(30)
            }
        }
        .frame(width: 760, height: 540)
        .tint(KiwiPalette.accent)
    }

    private var welcomeStep: some View {
        OnboardingPage(
            icon: "leaf.fill",
            eyebrow: "WELCOME TO PITCHKIWI",
            title: "Meet your prompt kiwi. 🥝",
            message: "Rambling in, useful words out. Whisper and Prompt mode run on this Mac, audio is discarded after transcription, and your voice is never uploaded."
        ) {
            HStack(spacing: 12) {
                PromisePill(icon: "lock.fill", text: "No account")
                PromisePill(icon: "icloud.slash.fill", text: "No cloud")
                PromisePill(icon: "waveform.badge.minus", text: "No saved audio")
            }
        }
    }

    private var controlsStep: some View {
        OnboardingPage(
            icon: "keyboard",
            eyebrow: "ONE KEY, TWO MODES",
            title: "Hold, speak, release. Easy. 🥝",
            message: "Use the Fn/Globe key from any normal text field. PitchKiwi places the finished transcript at the cursor without pressing Return or submitting anything."
        ) {
            HStack(spacing: 14) {
                GestureCard(keys: ["fn"], title: "Push to talk", detail: "Hold while speaking · release to insert")
                GestureCard(keys: ["fn", "fn"], title: "Hands-free", detail: "Double-press · press once to stop")
            }
        }
    }

    private var permissionsStep: some View {
        OnboardingPage(
            icon: "hand.raised.fill",
            eyebrow: "MAC PERMISSIONS",
            title: "Two permissions. Nothing more.",
            message: "Microphone lets PitchKiwi hear you. Accessibility lets it detect Fn and insert text into the app you were already using."
        ) {
            VStack(spacing: 10) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    detail: "Capture speech in memory",
                    isGranted: model.microphoneAuthorized,
                    buttonTitle: "Allow microphone",
                    action: model.requestMicrophone
                )
                PermissionRow(
                    icon: "cursorarrow.click.2",
                    title: "Accessibility",
                    detail: "Use Fn and insert at the cursor",
                    isGranted: model.accessibilityAuthorized,
                    buttonTitle: "Open Settings",
                    action: model.requestAccessibility
                )
            }
            .frame(maxWidth: 560)
        }
    }

    private var readyStep: some View {
        OnboardingPage(
            icon: "checkmark",
            eyebrow: "YOU'RE READY",
            title: "Pitch your first prompt.",
            message: "Choose Prompt mode, open your coding tool or AI chat, hold Fn, and ramble naturally. PitchKiwi will remove verbal clutter and organize only what you actually said."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Try saying")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("“Build a small Swift function that validates an email address.”")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Label("The first transcription may be slower while the local model warms up.", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: 560)
            .kiwiGlass(cornerRadius: 16)
        }
    }
}

private struct OnboardingPage<Content: View>: View {
    let icon: String
    let eyebrow: String
    let title: String
    let message: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(KiwiPalette.accent.opacity(0.18))
                    .frame(width: 86, height: 86)
                Circle()
                    .stroke(KiwiPalette.accent.opacity(0.32), lineWidth: 1)
                    .frame(width: 86, height: 86)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(KiwiPalette.accent)
            }

            VStack(spacing: 8) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(KiwiPalette.accent)
                Text(title)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 580)
            }

            content()
        }
        .padding(.horizontal, 44)
    }
}

private struct PromisePill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .kiwiGlass(cornerRadius: 999)
    }
}

private struct GestureCard: View {
    let keys: [String]
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    Text(key)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .frame(width: 38, height: 30)
                        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                }
            }
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 265, alignment: .leading)
        .kiwiGlass(cornerRadius: 16)
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let isGranted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(KiwiPalette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .kiwiGlass(cornerRadius: 14)
    }
}

private enum KiwiPalette {
    static let accent = Color(red: 0.46, green: 0.66, blue: 0.08)
    static let flesh = Color(red: 0.74, green: 0.92, blue: 0.28)
    static let skin = Color(red: 0.42, green: 0.27, blue: 0.12)
    static let cream = Color(red: 0.96, green: 0.94, blue: 0.84)
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(KiwiPalette.flesh)
                    .frame(width: 34, height: 34)
                Text("🥝")
                    .font(.system(size: 21))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("PitchKiwi").font(.headline)
                Text("LOCAL PROMPT VOICE")
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
                .foregroundStyle(KiwiPalette.accent)
            Text("History \(store.retention == .never ? "off" : "on") · Context \(store.contextEnabled ? "on" : "off")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Audio is never saved")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .kiwiGlass(cornerRadius: 14)
    }
}

private struct HomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var store: LocalStore

    init(model: AppModel) {
        self.model = model
        store = model.store
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "🥝 RAMBLE IN. CLEAR PROMPT OUT.",
                    title: "Turn a messy thought into something your agent can act on.",
                    subtitle: store.dictationMode == .prompt
                        ? "Prompt mode cleans and structures what you said, then can add a reusable agent brief at the length you choose—without a second AI model."
                        : "Dictate mode preserves your order and voice while removing obvious filler, repeated words, and repeated phrases."
                )

                HStack(spacing: 14) {
                    StatusCard(title: "Microphone", value: model.microphoneAuthorized ? "Ready" : "Needs access", icon: "mic.fill", ready: model.microphoneAuthorized)
                    StatusCard(title: "Whisper model", value: model.modelURL?.lastPathComponent ?? "Import model", icon: "cpu", ready: model.modelReady)
                    StatusCard(title: "Insertion", value: model.accessibilityAuthorized ? "Ready" : "Needs access", icon: "cursorarrow.click.2", ready: model.accessibilityAuthorized)
                }

                if !model.accessibilityAuthorized {
                    Button {
                        model.requestAccessibility()
                    } label: {
                        Label("Enable cross-app insertion", systemImage: "hand.raised.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 16) {
                    Picker("Output mode", selection: $store.dictationMode) {
                        Text("✍️ Dictate").tag(DictationMode.dictate)
                        Text("🥝 Prompt").tag(DictationMode.prompt)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 230)

                    Button {
                        model.toggleDictation()
                    } label: {
                        Label(
                            model.phase == .listening ? "Stop listening" : (store.dictationMode == .prompt ? "Start prompt" : "Start dictation"),
                            systemImage: model.phase == .listening ? "stop.fill" : "mic.fill"
                        )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KiwiPalette.accent)

                    KeyCap(text: "fn", detail: "hold · double-press hands-free")
                }

                if store.dictationMode == .prompt {
                    HStack(spacing: 14) {
                        Label("Prompt length", systemImage: "text.line.last.and.arrowtriangle.forward")
                            .font(.headline)
                        Picker("Prompt length", selection: $store.promptLength) {
                            ForEach(PromptLength.allCases) { length in
                                Text(length.title).tag(length)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 310)
                        Text(store.promptLength.explanation)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(14)
                    .kiwiGlass(cornerRadius: 14)
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
                            Button(model.showingOriginalTranscript ? "Show cleaned" : "Show original") {
                                model.toggleOriginalTranscript()
                            }
                            .disabled(!model.hasTranscriptAlternative)
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
        .kiwiGlass(cornerRadius: 16)
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
        .kiwiGlass(cornerRadius: 11)
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
                PageHeader(eyebrow: "HOW YOUR WORDS LAND", title: "Styles", subtitle: "Both modes are deterministic, inspectable, and local—no second AI model required.")

                SettingCard(icon: "chevron.left.forwardslash.chevron.right", title: "Code & prompts", description: "Preserve Markdown and translate spoken developer notation such as dot env, dash dash force, and casing commands.") {
                    Toggle("Developer formatting", isOn: $store.developerMode)
                }

                SettingCard(icon: "terminal", title: "Terminal safety", description: "PitchKiwi inserts text only. It never synthesizes Return or executes the command.") {
                    Label("Always on", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                }

                SettingCard(icon: "text.alignleft", title: "Clean dictation", description: "Remove verbal warm-ups, filler, repeated words, and repeated phrases while preserving uncertainty and intent.") {
                    Text("Always on").foregroundStyle(.secondary)
                }

                SettingCard(icon: "list.bullet.rectangle", title: "Prompt length", description: "Short preserves only your content. Medium adds a compact execution brief. Detailed adds workflow, safeguards, validation, and deliverable instructions. The added text is a fixed local template—not generated facts.") {
                    Picker("Prompt length", selection: $store.promptLength) {
                        ForEach(PromptLength.allCases) { length in Text(length.title).tag(length) }
                    }
                    .labelsHidden()
                    .frame(width: 130)
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
            PageHeader(eyebrow: "LOCAL TRANSFORMS", title: "Shape the thought, not the meaning.", subtitle: "Prompt Builder organizes your request and can append a fixed agent brief. It never answers the prompt or invents product facts.")

            HStack(spacing: 14) {
                TransformCard(icon: "wand.and.stars", title: "Polish", description: "Run conservative cleanup again and open the result in the scratchpad.") {
                    model.putLastInScratchpad()
                }
                TransformCard(icon: "curlybraces.square", title: "Prompt Builder", description: "Turn the last result into a (model.store.promptLength.title.lowercased()) agent prompt—without sending it to another model.") {
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
        .kiwiGlass(cornerRadius: 18, interactive: true)
    }
}

private struct InsightsView: View {
    @ObservedObject var store: LocalStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(eyebrow: "ON-DEVICE COUNTERS", title: "Insights", subtitle: "Only totals and timings are stored. No transcript content is needed for these metrics.")
                HStack(spacing: 14) {
                    MetricCard(value: "\(store.metrics.prompts)", label: "PROMPTS SHAPED", icon: "list.bullet.rectangle")
                    MetricCard(value: "\(store.metrics.developerFixes)", label: "DEV TERMS FIXED", icon: "chevron.left.forwardslash.chevron.right")
                    MetricCard(value: "\(store.metrics.dictations)", label: "KIWI SESSIONS", icon: "leaf.fill")
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Privacy-respecting by design").font(.headline)
                        Text("PitchKiwi records aggregate counts, not app titles, document names, audio, or dictated text when History is off.")
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
            Image(systemName: icon).font(.title3).foregroundStyle(KiwiPalette.accent)
            Text(value).font(.system(size: 34, weight: .semibold, design: .rounded))
            Text(label).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).tracking(0.8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kiwiGlass(cornerRadius: 18)
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

                SettingCard(icon: "cpu", title: "Whisper model", description: model.modelURL.map { "\($0.lastPathComponent) · base.en is fast; larger compatible .en models improve recognition but use more memory and time." } ?? "No local model found") {
                    Button("Import .bin…") { model.importModel() }
                }

                SettingCard(icon: "cursorarrow.click.2", title: "Accessibility", description: model.accessibilityAuthorized ? "Granted. PitchKiwi can insert at your cursor." : "Required to insert into other apps. Click Grant access, enable PitchKiwi, then return here.") {
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

                SettingCard(icon: "scope", title: "Nearby text context", description: "Off by default. When enabled, PitchKiwi reads up to 1,000 characters before and after the cursor, extracts at most 40 names or developer tokens for this dictation, then discards them. It never captures screenshots or full documents.") {
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
                .foregroundStyle(KiwiPalette.accent)
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
                .foregroundStyle(KiwiPalette.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 24)
            accessory()
        }
        .padding(18)
        .kiwiGlass(cornerRadius: 16)
    }
}

private struct KiwiBackdrop: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    KiwiPalette.flesh.opacity(0.14),
                    KiwiPalette.cream.opacity(0.07),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(KiwiPalette.skin.opacity(0.08))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 310, y: 250)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private extension View {
    @ViewBuilder
    func kiwiGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            if interactive {
                glassEffect(.regular.tint(.white.opacity(0.035)).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                glassEffect(.regular.tint(.white.opacity(0.035)), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.10)))
        }
#else
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.10)))
#endif
    }
}
