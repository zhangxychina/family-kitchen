import Foundation
import Speech
import AVFoundation

/// Listens once, in English and in Mandarin at the same time.
///
/// There is no language switch to set, because a family does not set one: somebody
/// says "we're out of milk" and somebody else says "牛奶没有了", often in the same
/// minute. One microphone feeds two recognisers, and whichever reading the kitchen
/// can actually act on is the one that is used.
///
/// Both run **on this iPhone**. A recogniser that cannot work offline is not used at
/// all, because the promise this app makes is that nothing leaves the phone, and
/// sending the family's kitchen talk to a server to save a tap would break it.
@MainActor final class VoiceListener: ObservableObject {
    /// What is being heard right now, for the family to watch as they speak.
    @Published private(set) var partial = ""
    @Published private(set) var isListening = false
    /// Set when listening could not start or could not finish. Always says what to do.
    @Published var failure: String?

    private let engine = AVAudioEngine()
    private var tasks: [SFSpeechRecognitionTask] = []
    private var requests: [String: SFSpeechAudioBufferRecognitionRequest] = [:]
    private var results: [String: SpokenReading] = [:]
    private var finished: Set<String> = []
    private var onDone: (([SpokenReading]) -> Void)?
    /// Set only under `--ui-testing`; see `scriptedReadings`.
    private var scripted: [SpokenReading]?

    /// The locales this app listens in, in the order they are offered.
    static let locales = ["en-US", "zh-CN"]

    /// The recognisers that exist on this phone and can work without a network.
    /// Empty means the phone cannot do this at all, and the family types instead.
    static func availableRecognizers() -> [SFSpeechRecognizer] {
        locales.compactMap { identifier in
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier)),
                  recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { return nil }
            return recognizer
        }
    }

    /// Whether the microphone button can do anything at all on this phone.
    static var canListen: Bool { !scriptedReadings.isEmpty || !availableRecognizers().isEmpty }

    /// Which of the two languages this phone can hear offline, in words.
    static func availabilityNote() -> String? {
        guard scriptedReadings.isEmpty else { return nil }
        let ready = availableRecognizers().map { $0.locale.identifier }
        if ready.count >= 2 { return nil }
        if ready.isEmpty {
            return "This iPhone cannot recognise speech offline yet. Add English and 简体中文 under Settings → General → Keyboard → Dictation Languages, then come back — or type instead, which works the same way."
        }
        let missing = ready.first?.hasPrefix("zh") == true ? "English" : "Mandarin · 中文"
        return "Only \(ready.first?.hasPrefix("zh") == true ? "Mandarin" : "English") can be recognised offline on this iPhone. Add \(missing) under Settings → General → Keyboard → Dictation Languages, or type instead."
    }

    /// A reading handed to the app instead of Apple's recogniser, for the UI tests.
    ///
    /// A simulator has no offline speech assets, so the microphone path cannot run
    /// there at all. This replaces the recogniser and nothing else: it proves what
    /// the app does *with* a transcript — choosing between the two languages,
    /// reading it back, waiting to be confirmed — and proves nothing whatever about
    /// whether the transcript was heard correctly. That still needs a real iPhone.
    ///
    /// Only honoured under `--ui-testing`, which already redirects storage away from
    /// a real family's kitchen.
    /// Written as `--voice-heard=zh-CN:0.82:家里已经有胡萝卜了`, repeatable.
    static var scriptedReadings: [SpokenReading] {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing") else { return [] }
        return arguments.compactMap { argument in
            guard argument.hasPrefix("--voice-heard=") else { return nil }
            let parts = argument.dropFirst("--voice-heard=".count).split(separator: ":", maxSplits: 2)
            guard parts.count == 3, let confidence = Double(parts[1]) else { return nil }
            return SpokenReading(locale: String(parts[0]), text: String(parts[2]), confidence: confidence)
        }
    }

    static func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }

    /// Starts listening. `completion` is called once, with a reading per language.
    func start(completion: @escaping ([SpokenReading]) -> Void) async {
        guard !isListening else { return }
        let scripted = Self.scriptedReadings
        if !scripted.isEmpty {
            self.scripted = scripted
            onDone = completion
            failure = nil
            partial = scripted.max { $0.confidence < $1.confidence }?.text ?? ""
            isListening = true
            return
        }
        let recognizers = Self.availableRecognizers()
        guard !recognizers.isEmpty else {
            failure = Self.availabilityNote()
            return
        }
        guard await Self.requestPermission() else {
            failure = "Family Kitchen needs the microphone and speech recognition to listen. Allow both in Settings, or type what you want to change."
            return
        }
        onDone = completion
        partial = ""; failure = nil
        results = [:]; finished = []

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            failure = "The microphone could not be opened: \(error.localizedDescription)"
            return
        }

        for recognizer in recognizers {
            let identifier = recognizer.locale.identifier
            let request = SFSpeechAudioBufferRecognitionRequest()
            // Nothing leaves this iPhone, which is the whole reason speech is offered
            // here at all.
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            requests[identifier] = request
            let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in self?.handle(identifier, result: result, error: error) }
            }
            tasks.append(task)
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // The requests are handed to the tap directly. Appending a buffer is safe from
        // the audio thread, and hopping to the main actor for every 23 milliseconds of
        // sound would cost latency and risk losing a buffer under load.
        let live = Array(requests.values)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            // One microphone, both recognisers: the same audio reaches each of them.
            live.forEach { $0.append(buffer) }
        }
        engine.prepare()
        do { try engine.start() } catch {
            failure = "The microphone could not be started: \(error.localizedDescription)"
            teardown()
            return
        }
        isListening = true
    }

    /// Stops listening and hands over whatever was heard.
    func stop() {
        guard isListening else { return }
        isListening = false
        if let scripted {
            self.scripted = nil
            results = Dictionary(uniqueKeysWithValues: scripted.map { ($0.locale, $0) })
            deliver()
            return
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        requests.values.forEach { $0.endAudio() }
        // A recogniser is allowed a moment to finish the last word before the reading
        // is called complete.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            deliver()
        }
    }

    /// Abandons a session without reporting anything — the family closed the sheet.
    func cancel() {
        onDone = nil
        scripted = nil
        isListening = false
        partial = ""
        teardown()
    }

    private func handle(_ identifier: String, result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let text = result.bestTranscription.formattedString
            let segments = result.bestTranscription.segments
            let confidence = segments.isEmpty ? 0
                : Double(segments.reduce(0) { $0 + $1.confidence }) / Double(segments.count)
            results[identifier] = SpokenReading(locale: identifier, text: text, confidence: confidence)
            if !text.isEmpty, text.count >= partial.count { partial = text }
            if result.isFinal { finished.insert(identifier) }
        }
        if error != nil { finished.insert(identifier) }
        if !isListening, finished.count >= requests.count { deliver() }
    }

    private func deliver() {
        guard let completion = onDone else { return }
        onDone = nil
        let candidates = Self.locales.compactMap { results[$0] }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        teardown()
        partial = ""
        completion(candidates)
    }

    private func teardown() {
        tasks.forEach { $0.cancel() }
        tasks = []
        requests = [:]
        if engine.isRunning { engine.inputNode.removeTap(onBus: 0); engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
