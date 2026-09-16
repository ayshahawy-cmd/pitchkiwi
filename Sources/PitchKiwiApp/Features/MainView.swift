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

    var title: String {
        switch self {
        case .home: "Command Deck"
        case .dictionary: "Project Dictionary"
        case .snippets: "Voice Macros"
        case .styles: "Output Rules"
        case .transforms: "Prompt Lab"
        case .insights: "Build Stats"
        case .settings: "Runtime & Privacy"
        }
    }

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
                    Section("Build tools") {
                        ForEach(Destination.allCases.filter { $0 != .settings }) { destination in
                            Label(destination.title, systemImage: destination.icon)
                                .tag(destination)
                        }
                    }
                    Section("Runtime") {
                        Label(Destination.settings.title, systemImage: Destination.settings.icon)
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
            icon: "terminal.fill",
            eyebrow: "VOICE INPUT FOR BUILDERS",
            title: "Talk to your tools like a teammate.",
            message: "PitchKiwi turns spoken implementation ideas into clean text for Codex, Claude Code, Cursor, terminals, issue trackers, and any editor—entirely on this Mac."
        ) {
            HStack(spacing: 12) {
                PromisePill(icon: "cpu", text: "Local speech engine")
                PromisePill(icon: "curlybraces.square", text: "Agent-ready prompts")
                PromisePill(icon: "terminal", text: "Terminal-safe")
            }
        }
    }

    private var controlsStep: some View {
        OnboardingPage(
            icon: "keyboard",
            eyebrow: "ONE KEY, ANY EDITOR",
            title: "Capture the thought without leaving the code.",
            message: "Use Fn from a source file, agent chat, terminal, pull request, or issue. PitchKiwi returns text to the same cursor and never presses Return or submits a command."
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
            eyebrow: "LOCAL RUNTIME ACCESS",
            title: "Two macOS bridges. No account.",
            message: "Microphone captures only an active dictation. Accessibility observes Fn and writes the result back into your current development tool."
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
            eyebrow: "READY TO BUILD",
            title: "Open your agent. Hold Fn. Build.",
            message: "Choose Agent Prompt, select Short, Medium, or Detailed, then speak naturally. PitchKiwi cleans the request and adds the level of execution guidance you chose."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Try saying")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("“In AuthService, add token refresh, keep secrets in .env, update the tests, and do not change the public API.”")
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
                Text("VOICE INPUT FOR BUILDERS")
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
            Label("OFFLINE RUNTIME", systemImage: "lock.fill")
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
                    eyebrow: "VOICE → AGENT INPUT",
                    title: "From half-formed thought to build-ready instruction.",
                    subtitle: store.dictationMode == .prompt
                        ? "Agent Prompt turns spoken intent into a structured implementation brief for coding agents, with the execution depth you choose."
                        : "Dictation keeps your technical wording intact while removing false starts, filler, and accidental repetition."
                )

                DeveloperToolStrip()

                HStack(spacing: 14) {
                    StatusCard(title: "Audio input", value: model.microphoneAuthorized ? "Ready" : "Needs access", icon: "mic.fill", ready: model.microphoneAuthorized)
                    StatusCard(title: "Local speech engine", value: model.modelURL?.lastPathComponent ?? "Import model", icon: "cpu", ready: model.modelReady)
                    StatusCard(title: "Editor bridge", value: model.accessibilityAuthorized ? "Ready" : "Needs access", icon: "cursorarrow.click.2", ready: model.accessibilityAuthorized)
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
                        Text("✍️ Dictation").tag(DictationMode.dictate)
                        Text("⌘ Agent Prompt").tag(DictationMode.prompt)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 230)

                    Button {
                        model.toggleDictation()
                    } label: {
                        Label(
                            model.phase == .listening ? "Stop capture" : (store.dictationMode == .prompt ? "Record agent prompt" : "Start dictation"),
                            systemImage: model.phase == .listening ? "stop.fill" : "mic.fill"
                        )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KiwiPalette.accent)

                    KeyCap(text: "fn", detail: "global capture key")
                }

                if store.dictationMode == .prompt {
                    HStack(spacing: 14) {
                        Label("Agent prompt depth", systemImage: "text.line.last.and.arrowtriangle.forward")
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
                            Label("Latest build input", systemImage: "text.bubble")
                                .font(.headline)
                            Spacer()
                            Text(model.statusText).font(.caption).foregroundStyle(.secondary)
                        }
                        if model.lastTranscript.isEmpty {
                            Text("Your latest dictation or agent prompt appears here. It stays in memory until you quit; history is off by default.")
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

private struct DeveloperToolStrip: View {
    private let tools: [(String, String)] = [
        ("terminal", "Codex"),
        ("chevron.left.forwardslash.chevron.right", "Claude Code"),
        ("cursorarrow.rays", "Cursor"),
        ("apple.terminal", "Terminal"),
        ("arrow.triangle.pull", "Pull requests"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            Text("BUILT FOR")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1.1)
            ForEach(tools, id: \.1) { icon, title in
                Label(title, systemImage: icon)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.primary.opacity(0.055), in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Built for Codex, Claude Code, Cursor, terminals, and pull requests")
    }
}

private struct DictionaryView: View {
    @ObservedObject var store: LocalStore
    @State private var spoken = ""
    @State private var written = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(eyebrow: "PROJECT-SPECIFIC TOKENS", title: "Project Dictionary", subtitle: "Lock in framework names, identifiers, repositories, environment variables, and internal terminology. Everything stays on this Mac.")
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
            PageHeader(eyebrow: "REUSABLE DEV BLOCKS", title: "Voice Macros", subtitle: "Speak one trigger to insert a PR checklist, debugging template, commit format, or prompt block you use repeatedly.")
            VStack(spacing: 10) {
                HStack {
                    TextField("Name", text: $name)
                    TextField("Spoken trigger", text: $trigger)
                }
                TextField("Expansion", text: $expansion, axis: .vertical)
                    .lineLimit(2...5)
                HStack {
                    Spacer()
                    Button("Add voice macro") {
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
                PageHeader(eyebrow: "COMPILER FOR YOUR SPEECH", title: "Output Rules", subtitle: "Choose how spoken developer language becomes code-aware text and agent instructions. Every rule runs locally and is inspectable.")

                SettingCard(icon: "chevron.left.forwardslash.chevron.right", title: "Developer syntax", description: "Preserve Markdown and compile spoken notation such as dot env, dash dash force, camel case, snake case, and fenced code blocks.") {
                    Toggle("Compile syntax", isOn: $store.developerMode)
                }

                SettingCard(icon: "terminal", title: "Terminal safety", description: "PitchKiwi inserts text only. It never synthesizes Return or executes the command.") {
                    Label("Always on", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                }

                SettingCard(icon: "text.alignleft", title: "Intent cleanup", description: "Remove verbal warm-ups, false starts, filler, and repetition while preserving uncertainty, negation, identifiers, and scope.") {
                    Text("Always on").foregroundStyle(.secondary)
                }

                SettingCard(icon: "list.bullet.rectangle", title: "Agent prompt depth", description: "Short compiles only your request. Medium adds an execution contract. Detailed adds repository inspection, scope safeguards, validation, and delivery requirements. Templates are fixed and local.") {
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
            PageHeader(eyebrow: "PROMPT WORKBENCH", title: "Compile speech into agent input.", subtitle: "Rework the latest capture without leaving the Mac. PitchKiwi structures the request but never performs the task or invents repository facts.")

            HStack(spacing: 14) {
                TransformCard(icon: "wand.and.stars", title: "Re-run cleanup", description: "Apply conservative intent cleanup again and open the result in the local workbench.") {
                    model.putLastInScratchpad()
                }
                TransformCard(icon: "curlybraces.square", title: "Compile agent prompt", description: "Turn the last result into a \(model.store.promptLength.title.lowercased())-depth coding-agent prompt without another model.") {
                    model.makePromptFromLast()
                }
            }

            GroupBox("Prompt workbench — local only") {
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
            Button("Use latest capture", action: action)
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
                PageHeader(eyebrow: "LOCAL BUILD TELEMETRY", title: "Build Stats", subtitle: "See how often voice became agent input or developer syntax. Counters contain no app names, repository names, or transcript content.")
                HStack(spacing: 14) {
                    MetricCard(value: "\(store.metrics.prompts)", label: "PROMPTS SHAPED", icon: "list.bullet.rectangle")
                    MetricCard(value: "\(store.metrics.developerFixes)", label: "DEV TERMS FIXED", icon: "chevron.left.forwardslash.chevron.right")
                    MetricCard(value: "\(store.metrics.dictations)", label: "VOICE CAPTURES", icon: "waveform")
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Metrics without repository surveillance").font(.headline)
                        Text("PitchKiwi records aggregate counts—not editor names, repository paths, document titles, audio, or dictated text when History is off.")
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
                PageHeader(eyebrow: "LOCAL RUNTIME CONFIG", title: "Runtime & Privacy", subtitle: "Configure the capture key, local model, editor bridge, retention, and bounded context. No account and no cloud transcription.")

                SettingCard(icon: "keyboard", title: "Global capture key", description: "Hold fn from an editor or agent chat and release to insert. Double-press for hands-free capture; press once more to stop.") {
                    Text("fn")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }

                SettingCard(icon: "cpu", title: "Local speech model", description: model.modelURL.map { "\($0.lastPathComponent) · base.en is fast; larger compatible English models improve technical-word recognition but use more memory and time." } ?? "No local model found") {
                    Button("Import .bin…") { model.importModel() }
                }

                SettingCard(icon: "cursorarrow.click.2", title: "Editor bridge", description: model.accessibilityAuthorized ? "Granted. PitchKiwi can return text to the active cursor." : "Required for the global Fn key and cross-app insertion. Click Grant access, enable PitchKiwi, then return here.") {
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
