import SwiftUI
import AppKit

enum ReadMode: String, CaseIterable, Identifiable {
    case sequential = "Sequential taps"
    case spatial = "Trackpad grid"
    var id: String { rawValue }
}

@MainActor
final class Model: ObservableObject {
    @Published var text = "Hello World 123" { didSet { textChanged() } }
    @Published var mode: ReadMode = .sequential { didSet { modeChanged() } }
    @Published var position = 0
    @Published var isPlaying = false
    @Published var status = "Starting."

    // sequential timing (milliseconds)
    @Published var tapLength = 0 { didSet { pushTiming() } }
    @Published var tapGap = 120 { didSet { pushTiming() } }
    @Published var dotPause = 400 { didSet { pushTiming() } }
    @Published var charPause = 800 { didSet { pushTiming() } }
    @Published var wordPause = 1400 { didSet { pushTiming() } }
    @Published var rightStrong = false { didSet { pushTiming() } }
    @Published var waveform = 4 { didSet { pushTiming(); pushConfig() } }

    // spatial grid mode
    @Published var page = 0
    @Published var dotSpacing = 2.5 { didSet { pushConfig() } }
    @Published var hitRadius = 1.0 { didSet { pushConfig() } }
    @Published var spatialGap = 50 { didSet { pushConfig() } }
    @Published var calibrate = false { didSet { pushConfig() } }
    @Published var padWidth = 155.0 { didSet { pushConfig() } }
    @Published var padHeight = 99.0 { didSet { pushConfig() } }

    private let engine = Engine()
    private let seq: Sequencer
    private var allCells: [UInt8] = []
    private var hapticsReady = false

    init() {
        seq = Sequencer(engine: engine)
        seq.onPosition = { [weak self] i in
            DispatchQueue.main.async { self?.position = i }
        }
        seq.onDone = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPlaying = false
                self.status = "Finished."
            }
        }
        allCells = Braille.cells(for: text)
    }

    // MARK: setup

    func begin() {
        allCells = Braille.cells(for: text)
        pushTiming()
        if let err = engine.openHaptics() {
            status = "Haptics unavailable. \(err)"
            return
        }
        hapticsReady = true
        if let sz = engine.surfaceSize() { padWidth = sz.width; padHeight = sz.height }
        status = "Ready. Press Play, or Command Return. Each dot is taps: top row one, middle two, bottom three."
        modeChanged()
    }

    private func modeChanged() {
        guard hapticsReady else { return }
        if mode == .spatial {
            stopPlayback()
            if let err = engine.start() { status = "Grid mode unavailable. \(err)"; return }
            pushConfig()
            refreshPage()
            status = "Trackpad grid mode. Slide one finger over the trackpad."
        } else {
            engine.stop()
            status = "Sequential mode. Press Play."
        }
    }

    private func textChanged() {
        stopPlayback()
        allCells = Braille.cells(for: text)
        position = 0
        page = 0
        refreshPage()
    }

    // MARK: sequential transport

    var cellCount: Int { allCells.count }

    var positionLabel: String {
        guard !allCells.isEmpty else { return "No text." }
        let p = min(position, allCells.count - 1)
        return "Cell \(p + 1) of \(allCells.count). Dots \(dotsDescription(allCells[p]))."
    }

    private func dotsDescription(_ c: UInt8) -> String {
        if c == 0 { return "none, space" }
        return (0..<6).filter { (c >> UInt8($0)) & 1 == 1 }.map { String($0 + 1) }.joined(separator: " ")
    }

    private func pushTiming() {
        var t = SeqTiming()
        t.waveform = Int32(waveform)
        t.rightWaveform = rightStrong ? 6 : Int32(waveform)
        t.tapLengthMS = tapLength
        t.tapGapMS = tapGap
        t.dotPauseMS = dotPause
        t.charPauseMS = charPause
        t.wordPauseMS = wordPause
        seq.timing = t
    }

    private func stopPlayback() {
        seq.stop()
        isPlaying = false
    }

    func playPause() {
        guard hapticsReady, !allCells.isEmpty else { return }
        if isPlaying {
            stopPlayback()
            status = "Paused at cell \(position + 1)."
        } else {
            if position >= allCells.count { position = 0 }
            isPlaying = true
            status = "Playing."
            seq.play(cells: allCells, from: position, single: false)
        }
    }

    private func playOne(at i: Int) {
        guard hapticsReady, !allCells.isEmpty else { return }
        stopPlayback()
        position = min(max(i, 0), allCells.count - 1)
        status = "Cell \(position + 1) of \(allCells.count)."
        seq.play(cells: allCells, from: position, single: true)
    }

    func stepForward() { playOne(at: position + 1) }
    func stepBack() { playOne(at: position - 1) }
    func repeatCurrent() { playOne(at: position) }
    func restart() { stopPlayback(); playOne(at: 0) }

    private var wordStarts: [Int] {
        allCells.indices.filter { allCells[$0] != 0 && ($0 == 0 || allCells[$0 - 1] == 0) }
    }
    func nextWord() {
        if let n = wordStarts.first(where: { $0 > position }) { playOne(at: n) } else { playOne(at: max(allCells.count - 1, 0)) }
    }
    func previousWord() {
        if let p = wordStarts.last(where: { $0 < position }) { playOne(at: p) } else { playOne(at: 0) }
    }

    func testPattern() {
        guard hapticsReady else { return }
        engine.testPulse()
        status = "Test: one tap, then two, then three."
    }

    // MARK: spatial grid

    private func pushConfig() {
        var c = engine.currentConfig()
        c.dotSpacingMM = dotSpacing
        c.hitRadiusMM = hitRadius
        c.waveform = Int32(waveform)
        c.calibrate = calibrate
        c.tapGapMS = spatialGap
        c.padWidthMM = padWidth
        c.padHeightMM = padHeight
        engine.setConfig(c)
        refreshPage()
    }

    var perPage: Int { Engine.cellsPerPage(engine.currentConfig()) }
    var pageCount: Int { max(1, Int((Double(allCells.count) / Double(perPage)).rounded(.up))) }
    var pageCells: [UInt8] {
        let start = min(page * perPage, allCells.count)
        return Array(allCells[start..<min(start + perPage, allCells.count)])
    }
    var pageBraille: String { Braille.unicode(pageCells) }
    var layoutSummary: String {
        let c = engine.currentConfig()
        return "\(Engine.columns(c)) cells across, \(Engine.lines(c)) lines down, \(perPage) cells per page."
    }

    func refreshPage() {
        if page >= pageCount { page = pageCount - 1 }
        if page < 0 { page = 0 }
        engine.setCells(pageCells)
    }
    func nextPage() { if page < pageCount - 1 { page += 1 }; refreshPage() }
    func prevPage() { if page > 0 { page -= 1 }; refreshPage() }
}
