import SwiftUI

public struct MinecraftTextParser {
    private static let colorMap: [Character: Color] = [
        "0": Color.black,
        "1": Color(red: 0, green: 0, blue: 0.67),
        "2": Color(red: 0, green: 0.67, blue: 0),
        "3": Color(red: 0, green: 0.67, blue: 0.67),
        "4": Color(red: 0.67, green: 0, blue: 0),
        "5": Color(red: 0.67, green: 0, blue: 0.67),
        "6": Color(red: 1.0, green: 0.67, blue: 0),
        "7": Color(red: 0.67, green: 0.67, blue: 0.67),
        "8": Color(red: 0.33, green: 0.33, blue: 0.33),
        "9": Color(red: 0.33, green: 0.33, blue: 1.0),
        "a": Color(red: 0.33, green: 1.0, blue: 0.33),
        "b": Color(red: 0.33, green: 1.0, blue: 1.0),
        "c": Color(red: 1.0, green: 0.33, blue: 0.33),
        "d": Color(red: 1.0, green: 0.33, blue: 1.0),
        "e": Color(red: 1.0, green: 1.0, blue: 0.33),
        "f": Color.white
    ]

    public static func parse(_ text: String) -> AttributedString {
        var attributed = AttributedString()
        let chars = Array(text)
        var i = 0

        var currentColor: Color = AppTheme.textPrimary
        var isBold = false
        var isItalic = false

        while i < chars.count {
            if (chars[i] == "§" || chars[i] == "&") && i + 1 < chars.count {
                let code = Character(chars[i + 1].lowercased())
                if let col = colorMap[code] {
                    currentColor = col
                    i += 2
                    continue
                } else if code == "l" {
                    isBold = true
                    i += 2
                    continue
                } else if code == "o" {
                    isItalic = true
                    i += 2
                    continue
                } else if code == "r" {
                    currentColor = AppTheme.textPrimary
                    isBold = false
                    isItalic = false
                    i += 2
                    continue
                }
            }

            var part = AttributedString(String(chars[i]))
            part.foregroundColor = currentColor
            if isBold {
                part.font = .system(size: 14, weight: .bold)
            }
            if isItalic {
                part.font = .system(size: 14).italic()
            }
            attributed.append(part)
            i += 1
        }

        return attributed
    }
}
