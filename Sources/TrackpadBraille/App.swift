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
                .frame(minWidth: 480, minHeight: 520)
                .onAppear { model.begin() }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section("Text to read") {
                TextField("Text", text: $model.text)
                    .accessibilityLabel("Text to read as braille")
            }
            Section("Page") {
                Text("Page \(model.page + 1) of \(model.pageCount)")
                Text(model.pageBraille)
                    .font(.system(size: 28))
                    .accessibilityLabel("Braille on this page: \(model.pageCells.count) cells")
                Text(model.layoutSummary)
                HStack {
                    Button("Previous page") { model.prevPage() }
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button("Next page") { model.nextPage() }
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                }
            }
            Section("Haptics") {
                Text(model.status)
                Toggle("Haptics on", isOn: $model.hapticsOn)
                Button("Test one tap") { model.testPulse() }
                Toggle("Calibration: tap on every dot position", isOn: $model.calibrate)
                Picker("Tap strength", selection: $model.waveform) {
                    Text("Weak click").tag(1)
                    Text("Strong click").tag(2)
                    Text("Light tap").tag(4)
                    Text("Medium tap").tag(5)
                    Text("Strong tap").tag(6)
                    Text("Soft thud").tag(15)
                    Text("Strong thud").tag(16)
                }
                VStack(alignment: .leading) {
                    Text("Dot spacing \(String(format: "%.1f", model.dotSpacing)) millimetres")
                    Slider(value: $model.dotSpacing, in: 2...6, step: 0.5)
                        .accessibilityLabel("Dot spacing in millimetres")
                }
                VStack(alignment: .leading) {
                    Text("Dot touch radius \(String(format: "%.2f", model.hitRadius)) millimetres")
                    Slider(value: $model.hitRadius, in: 0.5...2.5, step: 0.25)
                        .accessibilityLabel("Dot hit radius in millimetres")
                }
            }
            Section("Trackpad size") {
                Stepper("Gap between taps \(model.tapGap) milliseconds", value: $model.tapGap, in: 30...120, step: 10)
                Stepper("Width \(Int(model.padWidth)) millimetres", value: $model.padWidth, in: 100...200, step: 1)
                Stepper("Height \(Int(model.padHeight)) millimetres", value: $model.padHeight, in: 60...140, step: 1)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
