import Foundation

/// Grade 1 (uncontracted) 6-dot braille.
/// A cell is a bitmask: bit 0 = dot 1, bit 1 = dot 2, ... bit 5 = dot 6.
///
///   dot1 dot4
///   dot2 dot5
///   dot3 dot6
enum Braille {
    private static func mask(_ dots: [Int]) -> UInt8 {
        dots.reduce(0) { $0 | (1 << UInt8($1 - 1)) }
    }

    private static let letters: [Character: UInt8] = {
        let table: [(String, [Int])] = [
            ("a", [1]), ("b", [1, 2]), ("c", [1, 4]), ("d", [1, 4, 5]), ("e", [1, 5]),
            ("f", [1, 2, 4]), ("g", [1, 2, 4, 5]), ("h", [1, 2, 5]), ("i", [2, 4]), ("j", [2, 4, 5]),
            ("k", [1, 3]), ("l", [1, 2, 3]), ("m", [1, 3, 4]), ("n", [1, 3, 4, 5]), ("o", [1, 3, 5]),
            ("p", [1, 2, 3, 4]), ("q", [1, 2, 3, 4, 5]), ("r", [1, 2, 3, 5]), ("s", [2, 3, 4]), ("t", [2, 3, 4, 5]),
            ("u", [1, 3, 6]), ("v", [1, 2, 3, 6]), ("w", [2, 4, 5, 6]), ("x", [1, 3, 4, 6]),
            ("y", [1, 3, 4, 5, 6]), ("z", [1, 3, 5, 6]),
        ]
        var d: [Character: UInt8] = [:]
        for (c, dots) in table { d[Character(c)] = mask(dots) }
        return d
    }()

    // Digits 1-9, 0 use the letters a-j after a number sign.
    private static let digitLetters: [Character: Character] = [
        "1": "a", "2": "b", "3": "c", "4": "d", "5": "e",
        "6": "f", "7": "g", "8": "h", "9": "i", "0": "j",
    ]

    private static let punctuation: [Character: UInt8] = [
        ",": mask([2]), ";": mask([2, 3]), ":": mask([2, 5]), ".": mask([2, 5, 6]),
        "!": mask([2, 3, 5]), "?": mask([2, 3, 6]), "'": mask([3]), "-": mask([3, 6]),
        "\"": mask([2, 3, 6]), "(": mask([2, 3, 5, 6]), ")": mask([2, 3, 5, 6]),
    ]

    static let numberSign: UInt8 = mask([3, 4, 5, 6])
    static let capitalSign: UInt8 = mask([6])

    /// Convert text to braille cells. Unknown characters become a blank cell.
    static func cells(for text: String) -> [UInt8] {
        var out: [UInt8] = []
        var inNumber = false
        for ch in text {
            if let lowerLetter = ch.lowercased().first, ch.isLetter, let m = letters[lowerLetter] {
                inNumber = false
                if ch.isUppercase { out.append(capitalSign) }
                out.append(m)
            } else if let l = digitLetters[ch], let m = letters[l] {
                if !inNumber { out.append(numberSign); inNumber = true }
                out.append(m)
            } else if let m = punctuation[ch] {
                inNumber = false
                out.append(m)
            } else {
                inNumber = false
                out.append(0) // space or unknown
            }
        }
        return out
    }

    /// Unicode braille pattern for a cell (U+2800 block uses the same bit order).
    static func unicode(_ cell: UInt8) -> Character {
        Character(UnicodeScalar(0x2800 + UInt32(cell))!)
    }

    static func unicode(_ cells: [UInt8]) -> String {
        String(cells.map { unicode($0) })
    }
}
