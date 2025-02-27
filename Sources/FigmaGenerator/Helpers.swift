class Parser {
    var customThemeGroupedColors: [String?: [ColorStyle]]

    private var themeKeys: [String] = []

    init(colors: BrandThemeColors) {
        let uniqueThemeStyles = colors.first?.value ?? []
        self.customThemeGroupedColors = Dictionary(grouping: uniqueThemeStyles, by: { $0.info.customTheme })
        configure()
    }

    init(colors: [ColorStyle]) {
        self.customThemeGroupedColors = Dictionary(grouping: colors, by: { $0.info.customTheme })
        configure()
    }

    private func configure() {
        let customThemeKeys = customThemeGroupedColors.keys.compactMap { $0 }
        self.themeKeys = CustomThemeSorter(customThemes: customThemeKeys).sorted()
    }

    func getThemeOptions() -> [OptionEnum] {
        return themeKeys.compactMap { OptionEnum(caseKey: $0.replacingOccurrences(of: "Theme", with: ""), rawValue: $0) }
    }

    func getUniqueColors() -> [ColorStyle] {
        var uniqueColors: [ColorStyle] = []
        uniqueColors.append(contentsOf: customThemeGroupedColors[nil] ?? [])
        if let firstTheme = themeKeys.first {
            uniqueColors.append(contentsOf: customThemeGroupedColors[firstTheme] ?? [])
        }
        return uniqueColors
    }
}

class ColorNameSplitter {
    var fullColorName: String

    init(fullColorName: String) {
        self.fullColorName = fullColorName
    }

    func getColorInfo() -> ColorInfo? {
        guard let brandIndex = fullColorName.firstIndex(of: "/") else { return nil }
        var tempName = fullColorName
        var colorInfo = ColorInfo()
        colorInfo.brand = String(tempName[..<brandIndex])
        tempName = String(tempName[tempName.index(after: brandIndex)...])

        guard let systemThemeIndex = tempName.firstIndex(of: "/") else { return nil }
        colorInfo.systemTheme = String(tempName[..<systemThemeIndex])
        tempName = String(tempName[tempName.index(after: systemThemeIndex)...])

        if let themeIndex = tempName.firstIndex(of: "/"), String(tempName[..<themeIndex]) == "Theme" {
            tempName = String(tempName[tempName.index(after: themeIndex)...])
            if let customThemeIndex = tempName.firstIndex(of: "/") {
                colorInfo.customTheme = String(tempName[..<customThemeIndex])
                tempName = String(tempName[tempName.index(after: customThemeIndex)...])
            }
        }

        colorInfo.colorName = tempName
        return colorInfo
    }
}

class CustomThemeSorter {
    private var customThemes: [String] = []

    private let ordinalToNumber: [String: Int] = [
        "First": 1, "Second": 2, "Third": 3, "Fourth": 4, "Fifth": 5,
        "Sixth": 6, "Seventh": 7, "Eighth": 8, "Ninth": 9, "Tenth": 10,
        "Eleventh": 11, "Twelfth": 12, "Thirteenth": 13, "Fourteenth": 14,
        "Fifteenth": 15, "Sixteenth": 16, "Seventeenth": 17, "Eighteenth": 18,
        "Nineteenth": 19, "Twentieth": 20, "Thirtieth": 30, "Fortieth": 40,
        "Fiftieth": 50, "Sixtieth": 60, "Seventieth": 70, "Eightieth": 80, "Ninetieth": 90,
        "Hundredth": 100, "Thousandth": 1000
    ]

    init(customThemes: [String]) {
        self.customThemes = customThemes
    }

    func sorted() -> [String] {
        customThemes.sorted { wordToNumber($0) < wordToNumber($1) }
    }

    private func wordToNumber(_ word: String) -> Int {
        let themeNumber = word.replacingOccurrences(of: "Theme", with: "")
        var result = 0
        var current = 0
        var word = ""

        for char in themeNumber {
            if char.isUppercase {
                if let value = ordinalToNumber[word] {
                    if value == 100 || value == 1000 {
                        current *= value
                    } else {
                        current += value
                    }
                }
                word = String(char)
            } else {
                word.append(char)
            }
        }

        if let value = ordinalToNumber[word] {
            current += value
        }

        result += current
        return result
    }
}
