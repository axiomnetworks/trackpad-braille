import Foundation

struct SeqTiming {
    var waveform: Int32 = 4
    var rightWaveform: Int32 = 4
    var tapLengthMS = 0      // 0 = one short pulse; larger repeats pulses so the tap feels longer
    var tapGapMS = 120       // between taps inside one dot
    var dotPauseMS = 400     // between dots of one character
    var charPauseMS = 800    // between characters
    var wordPauseMS = 1400   // for a space
}

/// Plays braille cells as taps: dots in order 1..6, each dot = (row + 1) taps.
/// Top row (dots 1, 4) = 1 tap, middle (2, 5) = 2 taps, bottom (3, 6) = 3 taps.
final class Sequencer {
    private let engine: Engine
    private let lock = NSLock()
    private var token = 0
    private var _timing = SeqTiming()
    var onPosition: ((Int) -> Void)?
    var onDone: (() -> Void)?

    init(engine: Engine) { self.engine = engine }

    var timing: SeqTiming {
        get { lock.lock(); defer { lock.unlock() }; return _timing }
        set { lock.lock(); _timing = newValue; lock.unlock() }
    }

    func stop() { lock.lock(); token += 1; lock.unlock() }

    private func alive(_ my: Int) -> Bool { lock.lock(); defer { lock.unlock() }; return token == my }

    private func wait(_ ms: Int, _ my: Int) {
        var left = ms
        while left > 0 && alive(my) {
            let s = min(left, 10)
            usleep(UInt32(s * 1000))
            left -= s
        }
    }

    private func pulse(_ wf: Int32, _ lengthMS: Int, _ my: Int) {
        engine.pulse(wf)
        var done = 12
        while done < lengthMS && alive(my) {
            wait(12, my)
            engine.pulse(wf)
            done += 12
        }
    }

    private func playCell(_ c: UInt8, _ my: Int) {
        let t = timing
        var first = true
        for bit in 0..<6 where (c >> UInt8(bit)) & 1 == 1 {
            guard alive(my) else { return }
            if !first { wait(t.dotPauseMS, my) }
            first = false
            let taps = bit % 3 + 1
            let wf = bit >= 3 ? t.rightWaveform : t.waveform
            for k in 0..<taps {
                guard alive(my) else { return }
                pulse(wf, t.tapLengthMS, my)
                if k < taps - 1 { wait(t.tapGapMS, my) }
            }
        }
    }

    /// Play from `start` to the end, or just one character when `single`.
    func play(cells: [UInt8], from start: Int, single: Bool) {
        lock.lock(); token += 1; let my = token; lock.unlock()
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            var i = max(0, start)
            while i < cells.count {
                guard alive(my) else { return }
                onPosition?(i)
                let c = cells[i]
                if c == 0 {
                    if single { return }
                    wait(timing.wordPauseMS, my)
                } else {
                    playCell(c, my)
                    if single { return }
                    if i + 1 < cells.count && cells[i + 1] != 0 { wait(timing.charPauseMS, my) }
                }
                i += 1
            }
            if alive(my) { onDone?() }
        }
    }
}
