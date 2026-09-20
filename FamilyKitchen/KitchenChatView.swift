import SwiftUI

/// One thing somebody said or typed, and what the kitchen made of it.
private struct ChatTurn: Identifiable {
    let id = UUID()
    /// The words that were used, as heard or as typed.
    var heard: String
    /// Where they came from: "Typed", "Heard in English", "听到的中文".
    var source: String
    /// The other language's reading of the same breath, offered when it differs, so
    /// a family that switches mid-sentence is never stuck with the wrong ear.
    var alternatives: [SpokenReading] = []
    var answer: KitchenAnswer
    var applied = false
    /// The kitchen exactly as it stood before this turn changed it.
    var before: FamilyState?
}

/// Say it or type it: the short way to change what is on the menu and what is on the
/// shopping list.
///
/// Everything here works the way the shop check does. A sentence is read on this
/// iPhone, what it was understood to mean is written back out in both languages, and
/// only a tap carries it out — because a recogniser that hears "melons" for "lemons"
/// must not be able to change tonight's dinner on its own.
struct KitchenChatView: View {
    @EnvironmentObject var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var listener = VoiceListener()
    @State private var turns: [ChatTurn] = []
    @State private var typed = ""
    @FocusState private var writing: Bool
    /// What this phone can hear, asked when the sheet opens rather than on every
    /// keystroke: building two recognisers is not free, and a SwiftUI body is
    /// evaluated constantly while somebody types.
    @State private var micNote: String?
    @State private var canListen = true

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        opening
                        ForEach(turns) { turn in bubble(turn).id(turn.id) }
                        if listener.isListening { listening }
                        Color.clear.frame(height: 1).id("end")
                    }.padding(20)
                }
                .background(Brand.paper)
                .onChange(of: turns.count) { _, _ in withAnimation { scroller.scrollTo("end") } }
                .onChange(of: listener.isListening) { _, _ in withAnimation { scroller.scrollTo("end") } }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle("Say what changed · 说一句")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .onAppear {
                micNote = VoiceListener.availabilityNote()
                canListen = VoiceListener.canListen
            }
            .onDisappear { listener.cancel() }
        }
    }

    // MARK: - The conversation

    @ViewBuilder private var opening: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(en: "Tell me what changed", zh: "把变化说给我听")
            Text("Say it or type it, in English or Mandarin. I will say back what I understood, and nothing changes until you tap to confirm.")
                .font(.footnote).foregroundStyle(.secondary)
            ForEach(KitchenTalk.examples.indices, id: \.self) { index in
                let example = KitchenTalk.examples[index]
                Button { submit(example.en, source: "Typed · 输入") } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.opening").font(.caption2).foregroundStyle(.tertiary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(example.en).font(.footnote)
                            Text(example.zh).font(.footnote).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
            if let micNote {
                Label(micNote, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Brand.clay)
            }
            InfoNote(title: "What this does and does not do · 能做什么，不能做什么", lines: [
                "Speech is recognised on this iPhone, in English and Mandarin at the same time. Nothing is uploaded and no recording is kept.",
                "It understands four things: what you already have at home, what you have run out of, what you have bought, and which dish goes on a day.",
                "It never acts by itself. Read what it understood, then tap to confirm.",
                "Food recorded this way has no shelf yet — confirm where it went in Kitchen or Put away."
            ])
        }.kitchenCard()
    }

    @ViewBuilder private var listening: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "waveform").foregroundStyle(Brand.green).symbolEffect(.variableColor)
            VStack(alignment: .leading, spacing: 4) {
                Text("Listening · 正在听").font(.caption.bold()).foregroundStyle(.secondary)
                Text(listener.partial.isEmpty ? "Speak now, then tap the microphone again." : listener.partial)
                    .font(.body)
            }
        }.kitchenCard()
    }

    @ViewBuilder private func bubble(_ turn: ChatTurn) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(turn.source).font(.caption.bold()).tracking(1).foregroundStyle(.secondary)
                Text("“\(turn.heard)”").font(.system(.body, design: .serif))
            }
            switch turn.answer {
            case .command(let command): reading(turn, command)
            case .chooseDish(let meal, let slotEN, let slotZH, let options):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Which one did you mean for \(slotEN)?").font(.headline)
                    Text("\(slotZH)要换成哪一道？").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(options, id: \.self) { option in
                        if let recipe = Catalog.recipe(option) {
                            Button { choose(turn, meal: meal, recipe: option) } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(recipe.en).font(.subheadline.bold())
                                    Text(recipe.zh).font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.bordered)
                        }
                    }
                }
            case .unsure(let en, let zh, let notes):
                VStack(alignment: .leading, spacing: 6) {
                    Text(en).font(.subheadline)
                    if !zh.isEmpty { Text(zh).font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(notes, id: \.self) { note in
                        Label(note, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            alternates(turn)
        }.kitchenCard()
    }

    @ViewBuilder private func reading(_ turn: ChatTurn, _ command: KitchenCommand) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(command.steps) { step in
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.en).font(.subheadline)
                    Text(step.zh).font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(command.notes, id: \.self) { note in
                Label(note, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Brand.clay)
            }
            if turn.applied {
                HStack {
                    Label("Done · 已完成", systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(Brand.protein)
                    Spacer()
                    if canUndo(turn) { Button("Undo · 撤销") { undo(turn) }.font(.footnote) }
                }
            } else {
                HStack(spacing: 12) {
                    Button("Do it · 就这么办") { apply(turn, command) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("kitchenChatApply")
                    Button("Not that · 不是这个") { drop(turn) }.buttonStyle(.bordered)
                }
            }
        }
    }

    /// The other language's reading, when it is not the one that was used.
    @ViewBuilder private func alternates(_ turn: ChatTurn) -> some View {
        let others = turn.alternatives.filter { $0.text != turn.heard && !$0.text.isEmpty }
        if !turn.applied, !others.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Also heard · 另一种听法").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(others) { candidate in
                    Button { submit(candidate.text, source: "Heard in \(candidate.languageEN) · \(candidate.languageZH)") } label: {
                        Text("\(candidate.languageZH): “\(candidate.text)”").font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Saying something

    @ViewBuilder private var composer: some View {
        HStack(spacing: 10) {
            TextField("Type a change · 输入要改的事", text: $typed, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .focused($writing)
                .submitLabel(.send)
                .onSubmit(send)
                .accessibilityIdentifier("kitchenChatField")
            Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Send")
                .accessibilityIdentifier("kitchenChatSend")
            Button(action: microphone) {
                Image(systemName: listener.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(listener.isListening ? Brand.clay : Brand.green)
            }
            .disabled(!canListen)
            .accessibilityLabel(listener.isListening ? "Stop listening" : "Speak a change")
            .accessibilityIdentifier("kitchenChatMic")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) {
            if let failure = listener.failure {
                Text(failure).font(.caption).foregroundStyle(Brand.clay)
                    .padding(.horizontal, 16).padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Brand.card)
                    .offset(y: -34)
            }
        }
    }

    private func send() {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        typed = ""; writing = false
        submit(text, source: "Typed · 输入")
    }

    private func microphone() {
        if listener.isListening { listener.stop(); return }
        writing = false
        Task { await listener.start { candidates in heard(candidates) } }
    }

    /// Hands the readings to the kitchen, which decides which ear to believe.
    private func heard(_ candidates: [SpokenReading]) {
        guard let choice = store.state.bestReading(among: candidates) else {
            turns.append(ChatTurn(heard: "", source: "Heard nothing · 没有听到",
                                  answer: .unsure(en: "I did not hear anything. Try again, closer to the phone, or type it.",
                                                  zh: "没有听到声音。请靠近手机再说一次，或者直接输入。")))
            return
        }
        submit(choice.text,
               source: "Heard in \(choice.languageEN) · \(choice.languageZH)",
               alternatives: candidates)
    }

    private func submit(_ text: String, source: String, alternatives: [SpokenReading] = []) {
        turns.append(ChatTurn(heard: text, source: source, alternatives: alternatives,
                              answer: store.state.interpret(text)))
    }

    // MARK: - Carrying it out

    private func apply(_ turn: ChatTurn, _ command: KitchenCommand) {
        guard let index = turns.firstIndex(where: { $0.id == turn.id }) else { return }
        let before = store.state
        guard store.update({ $0.perform(command) }) else { return }
        turns[index].applied = true
        turns[index].before = before
    }

    private func choose(_ turn: ChatTurn, meal: UUID, recipe: String) {
        guard let index = turns.firstIndex(where: { $0.id == turn.id }) else { return }
        turns[index].answer = store.state.swapCommand(meal: meal, to: recipe)
    }

    private func drop(_ turn: ChatTurn) {
        turns.removeAll { $0.id == turn.id }
    }

    /// Only the latest change can be taken back here. Anything older is undone where
    /// it lives — on the shopping list, or on the meal itself — so that putting one
    /// sentence back can never quietly discard the three that came after it.
    private func canUndo(_ turn: ChatTurn) -> Bool {
        turn.before != nil && turns.last(where: \.applied)?.id == turn.id
    }

    private func undo(_ turn: ChatTurn) {
        guard let index = turns.firstIndex(where: { $0.id == turn.id }), let before = turns[index].before else { return }
        guard store.update({ $0 = before }) else { return }
        turns[index].applied = false
        turns[index].before = nil
    }
}

/// Puts "say or type a change" within reach of the screens where things change.
struct KitchenChatAccess: ViewModifier {
    @EnvironmentObject var store: FamilyStore
    @State private var open = false
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { open = true } label: { Image(systemName: "text.bubble") }
                        .accessibilityLabel("Say or type a change")
                        .accessibilityIdentifier("openKitchenChat")
                }
            }
            .sheet(isPresented: $open) { KitchenChatView().environmentObject(store) }
    }
}

extension View {
    func kitchenChat() -> some View { modifier(KitchenChatAccess()) }
}
