import Foundation

/// Width of a character in half-width units: CJK and full-width forms take two.
private func width(of character: Character) -> Int {
    guard let scalar = character.unicodeScalars.first?.value else { return 1 }
    let wide = (0x1100...0x115F).contains(scalar) || (0x2E80...0xA4CF).contains(scalar)
        || (0xAC00...0xD7A3).contains(scalar) || (0xF900...0xFAFF).contains(scalar)
        || (0xFF00...0xFF60).contains(scalar) || scalar >= 0x1F300
    return wide ? 2 : 1
}

private func width(of text: Substring) -> Int {
    text.reduce(0) { $0 + width(of: $1) }
}

private func wrap(_ paragraph: Substring, lineWidth: Int) -> [String] {
    var lines: [String] = []
    var line = ""
    var used = 0
    for word in paragraph.split(separator: " ") {
        let wordWidth = width(of: word)
        let gap = line.isEmpty ? 0 : 1
        if used + gap + wordWidth <= lineWidth {
            if gap == 1 { line += " " }
            line += word
            used += gap + wordWidth
            continue
        }
        if !line.isEmpty {
            lines.append(line)
            line = ""
            used = 0
        }
        // A word wider than a line (or CJK text without spaces) is split by characters.
        for character in word {
            let characterWidth = width(of: character)
            if used + characterWidth > lineWidth, !line.isEmpty {
                lines.append(line)
                line = ""
                used = 0
            }
            line.append(character)
            used += characterWidth
        }
    }
    if !line.isEmpty { lines.append(line) }
    return lines
}

/// Splits an answer into screens of at most `linesPerPage` lines of `lineWidth` units.
public func pages(for text: String, lineWidth: Int, linesPerPage: Int) -> [String] {
    let lines = text
        .split(whereSeparator: \.isNewline)
        .flatMap { wrap($0, lineWidth: lineWidth) }
    return stride(from: 0, to: lines.count, by: linesPerPage).map { start in
        lines[start..<min(start + linesPerPage, lines.count)].joined(separator: "\n")
    }
}
