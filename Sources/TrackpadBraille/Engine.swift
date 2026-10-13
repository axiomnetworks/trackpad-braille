import Foundation

struct ReaderConfig {
    var padWidthMM: Double = 155      // replaced by the real size when the system reports it
    var padHeightMM: Double = 99
    var dotSpacingMM: Double = 2.5    // standard braille: dot to dot
    var cellPitchMM: Double = 6.0     // standard braille: cell to cell (width)
    var linePitchMM: Double = 10.0    // standard braille: line to line (height)
    var hitRadiusMM: Double = 1.0     // how close the finger must be to a dot
    var waveform: Int32 = 4           // short pulse used for every tap
    var tapGapMS: Int = 50            // pause between taps of one dot
    var calibrate: Bool = false       // true = every dot position pulses (learn the layout)
}

/// Lays braille cells out on the trackpad and fires a pulse when a finger crosses a raised dot.
final class Engine {
    private let mt = Multitouch()
    private let lock = NSLock()
    private var config = ReaderConfig()
    private var cells: [UInt8] = []
    private var dots: [(x: Double, y: Double, id: Int)] = []
    private var lastPos: (x: Double, y: Double)?
    private var lastDot = -1
    private var lastFire = Date.distantPast
    private(set) var running = false

    // MARK: layout

    private static let margin = 8.0
    static func pitch(_ c: ReaderConfig) -> Double { c.cellPitchMM }
    static func lineHeight(_ c: ReaderConfig) -> Double { c.linePitchMM }

    static func columns(_ c: ReaderConfig) -> Int {
        max(1, Int((c.padWidthMM - 2 * margin - c.dotSpacingMM) / pitch(c)) + 1)
    }
    static func lines(_ c: ReaderConfig) -> Int {
        max(1, Int((c.padHeightMM - 2 * margin - 2 * c.dotSpacingMM) / lineHeight(c)) + 1)
    }
    static func cellsPerPage(_ c: ReaderConfig) -> Int { columns(c) * lines(c) }

    private func rebuildDots() {
        let c = config
        let cols = Engine.columns(c)
        var list: [(x: Double, y: Double, id: Int)] = []
        for (i, cell) in cells.enumerated() {
            let col = i % cols, line = i / cols
            let ox = Engine.margin + Double(col) * Engine.pitch(c)
            let oy = Engine.margin + Double(line) * Engine.lineHeight(c)
            for bit in 0..<6 where c.calibrate || (cell >> UInt8(bit)) & 1 == 1 {
                // dots 1-3 left column top to bottom, dots 4-6 right column
                let dx = bit < 3 ? 0.0 : c.dotSpacingMM
                let dy = Double(bit % 3) * c.dotSpacingMM
                list.append((ox + dx, oy + dy, i * 6 + bit))
            }
        }
        dots = list
        lastDot = -1
    }

    // MARK: public control

    func setCells(_ newCells: [UInt8]) {
        lock.lock(); defer { lock.unlock() }
        cells = newCells
        rebuildDots()
    }

    func setConfig(_ new: ReaderConfig) {
        lock.lock(); defer { lock.unlock() }
        config = new
        rebuildDots()
    }

    func currentConfig() -> ReaderConfig {
        lock.lock(); defer { lock.unlock() }
        return config
    }

    /// Returns nil on success or an error message.
    func start() -> String? {
        if running { return nil }
        if let err = mt.open() { return err }
        mt.startTouches { [weak self] touches, count in self?.handle(touches, count) }
        running = true
        return nil
    }

    func stop() {
        mt.stopTouches()
        running = false
    }

    func testPulse() {
        let c = currentConfig()
        mt.fire(c.waveform, count: 1, gapMS: c.tapGapMS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [mt] in mt.fire(c.waveform, count: 2, gapMS: c.tapGapMS) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [mt] in mt.fire(c.waveform, count: 3, gapMS: c.tapGapMS) }
    }

    func surfaceSize() -> (width: Double, height: Double)? { mt.surfaceSizeMM() }

    // MARK: touch handling (runs on the multitouch thread)

    private func handle(_ touches: UnsafeMutableRawPointer?, _ count: Int) {
        lock.lock(); defer { lock.unlock() }
        guard let touches, count > 0 else { lastPos = nil; lastDot = -1; return }
        // first finger that is actually touching (state 3 = make, 4 = touching)
        var found: (Double, Double)?
        for i in 0..<count {
            let base = touches + i * Multitouch.touchStride
            let state = base.load(fromByteOffset: 20, as: Int32.self)
            if state == 3 || state == 4 {
                let nx = Double(base.load(fromByteOffset: 32, as: Float.self))
                let ny = Double(base.load(fromByteOffset: 36, as: Float.self))
                found = (nx * config.padWidthMM, (1 - ny) * config.padHeightMM)
                break
            }
        }
        guard let pos = found else { lastPos = nil; lastDot = -1; return }

        // walk from the last position to this one in ~1 mm steps so fast swipes can't skip dots
        let from = lastPos ?? pos
        let dist = hypot(pos.0 - from.0, pos.1 - from.1)
        let steps = max(1, Int((dist * 2).rounded(.up)))
        for s in 1...steps {
            let t = Double(s) / Double(steps)
            check(x: from.0 + (pos.0 - from.0) * t, y: from.1 + (pos.1 - from.1) * t)
        }
        lastPos = pos
    }

    private func check(x: Double, y: Double) {
        var hit = -1
        var best = config.hitRadiusMM
        for d in dots {
            let dd = hypot(d.x - x, d.y - y)
            if dd < best { best = dd; hit = d.id }
        }
        if hit != lastDot {
            lastDot = hit
            if hit >= 0 && Date().timeIntervalSince(lastFire) > 0.012 {
                lastFire = Date()
                mt.fire(config.waveform, count: hit % 6 % 3 + 1, gapMS: config.tapGapMS)
            }
        }
    }
}
