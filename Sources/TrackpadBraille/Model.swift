import SwiftUI
import AppKit

@MainActor
final class Model: ObservableObject {
    @Published var text = "Hello World 123" { didSet { refresh(announce: false) } }
    @Published var page = 0
    @Published var status = "Starting."
    @Published var hapticsOn = true { didSet { toggleHaptics() } }
    @Published var dotSpacing = 9.0 { didSet { pushConfig() } }
    @Published var hitRadius = 3.5 { didSet { pushConfig() } }
    @Published var waveform = 4 { didSet { pushConfig() } }
    @Published var calibrate = false { didSet { pushConfig() } }
    @Published var padWidth = 155.0 { didSet { pushConfig() } }
    @Published var padHeight = 99.0 { didSet { pushConfig() } }

    private let engine = Engine()
    private var allCells: [UInt8] = []

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

    func begin() {
        refresh(announce: false)
        if let err = engine.start() {
            status = "Haptics unavailable. \(err)"
        } else {
            status = "Trackpad ready. Rest a finger on the trackpad and slide it. You feel a tap on each raised dot."
        }
    }

    private func pushConfig() {
        var c = engine.currentConfig()
        c.dotSpacingMM = dotSpacing
        c.hitRadiusMM = hitRadius
        c.waveform = Int32(waveform)
        c.calibrate = calibrate
        c.padWidthMM = padWidth
        c.padHeightMM = padHeight
        engine.setConfig(c)
        refresh(announce: false)
    }

    private func toggleHaptics() {
        if hapticsOn { begin() } else { engine.stop(); status = "Haptics off." }
    }

    func refresh(announce: Bool) {
        allCells = Braille.cells(for: text)
        if page >= pageCount { page = pageCount - 1 }
        if page < 0 { page = 0 }
        engine.setCells(pageCells)
        if announce { speak("Page \(page + 1) of \(pageCount). \(pageCells.count) cells.") }
    }

    func nextPage() { if page < pageCount - 1 { page += 1 }; refresh(announce: true) }
    func prevPage() { if page > 0 { page -= 1 }; refresh(announce: true) }
    func testPulse() { engine.testPulse() }

    func speak(_ s: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: s, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
}
