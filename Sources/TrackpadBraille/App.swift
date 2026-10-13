import SwiftUI
import AppKit

@main
struct TrackpadBrailleApp: App {
    @StateObject private var model = Model()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Trackpad Braille") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 520, minHeight: 600)
                .onAppear { model.begin() }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section("Text to read") {
                TextField("Text", text: $model.text, axis: .vertical)
                    .accessibilityLabel("Text to read as braille")
            }
            Section("Mode") {
                Picker("Reading mode", selection: $model.mode) {
                    ForEach(ReadMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
            }
            if model.mode == .sequential {
                PlaybackSection()
            } else {
                GridSection()
            }
            TimingSection()
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PlaybackSection: View {
    @EnvironmentObject var model: Model
    var body: some View {
        Section("Playback") {
            Text(model.status)
            Text(model.positionLabel)
            Button(model.isPlaying ? "Pause" : "Play") { model.playPause() }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Previous character") { model.stepBack() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Next character") { model.stepForward() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            Button("Repeat character") { model.repeatCurrent() }
                .keyboardShortcut("r", modifiers: .command)
            Button("Previous word") { model.previousWord() }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button("Next word") { model.nextWord() }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Button("Back to start") { model.restart() }
        }
    }
}

struct TimingSection: View {
    @EnvironmentObject var model: Model
    var body: some View {
        Section("Taps and timing") {
            Button("Test taps: one, two, three") { model.testPattern() }
            Stepper("Tap length \(model.tapLength) milliseconds. Zero is one short pulse.",
                    value: $model.tapLength, in: 0...200, step: 12)
            Stepper("Gap between taps in a dot \(model.tapGap) milliseconds",
                    value: $model.tapGap, in: 40...400, step: 10)
            Stepper("Pause between dots \(model.dotPause) milliseconds",
                    value: $model.dotPause, in: 100...1500, step: 50)
            Stepper("Pause between characters \(model.charPause) milliseconds",
                    value: $model.charPause, in: 200...3000, step: 100)
            Stepper("Pause for a space \(model.wordPause) milliseconds",
                    value: $model.wordPause, in: 300...5000, step: 100)
            Toggle("Right column dots use a stronger tap", isOn: $model.rightStrong)
            Picker("Tap strength", selection: $model.waveform) {
                Text("Weak click").tag(1)
                Text("Strong click").tag(2)
                Text("Light tap").tag(4)
                Text("Medium tap").tag(5)
                Text("Strong tap").tag(6)
                Text("Soft thud").tag(15)
                Text("Strong thud").tag(16)
            }
        }
    }
}

struct GridSection: View {
    @EnvironmentObject var model: Model
    var body: some View {
        Section("Trackpad grid") {
            Text(model.status)
            Text("Page \(model.page + 1) of \(model.pageCount)")
            Text(model.pageBraille)
                .font(.system(size: 28))
                .accessibilityLabel("Braille on this page: \(model.pageCells.count) cells")
            Text(model.layoutSummary)
            Button("Previous page") { model.prevPage() }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .control])
            Button("Next page") { model.nextPage() }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .control])
            Toggle("Calibration: tap on every dot position", isOn: $model.calibrate)
            Stepper("Gap between taps in grid mode \(model.spatialGap) milliseconds",
                    value: $model.spatialGap, in: 30...120, step: 10)
            VStack(alignment: .leading) {
                Text("Dot spacing \(String(format: "%.1f", model.dotSpacing)) millimetres")
                Slider(value: $model.dotSpacing, in: 2...6, step: 0.5)
                    .accessibilityLabel("Dot spacing in millimetres")
            }
            VStack(alignment: .leading) {
                Text("Dot touch radius \(String(format: "%.2f", model.hitRadius)) millimetres")
                Slider(value: $model.hitRadius, in: 0.5...2.5, step: 0.25)
                    .accessibilityLabel("Dot touch radius in millimetres")
            }
            Stepper("Trackpad width \(Int(model.padWidth)) millimetres", value: $model.padWidth, in: 100...200, step: 1)
            Stepper("Trackpad height \(Int(model.padHeight)) millimetres", value: $model.padHeight, in: 60...140, step: 1)
        }
    }
}
