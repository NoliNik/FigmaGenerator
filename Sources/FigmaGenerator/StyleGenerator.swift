import Foundation

class StyleGenerator {
    private enum Constants {
        static let optionsEnumName = "ThemeColorType"
        static let schemeProtocolName = "ColorScheme"
        static let gradientsName = "Gradients"
    }
    
    let file: File
    private var colors: [ColorStyle]!
    private var brandColorsDictionary: BrandColors = [:]
    private var fonts: [FontStyle]!
    private var gradients: [Gradient] = []
    private var trimmedColorNamesCount: [String: Int] = [:]

    var trimEndingDigits: Bool = false
    var useExtendedSRGBColorspace: Bool = false
    var colorPrefix: String = "" {
        didSet {
            regenerateTrimMap()
        }
    }

    var source: String = ""
    var currentAppName: String = ""
    var currentAppOutputFolder: String = ""
    var brandsOutputFolder: String = ""
    var brandsToGenerate: [String] = []

    init(file: File) {
        self.file = file
    }

    private func process() {
        guard colors == nil else {
            return
        }
        
        colors = file.styles.compactMap { (key: String, value: Style) -> ColorStyle? in
            let colorInfo = file.findColor(styleID: key)
            if let color = colorInfo.color, let id = colorInfo.id, var info = ColorNameSplitter(fullColorName: value.name).getColorInfo() {
                let style = Style(key: value.key, name: info.colorName, styleType: value.styleType, description: value.description)
                info.id = id
                return ColorStyle(style: style, color: color, info: info)
            } else {
                return nil
            }
        }
        colors.sort { $0.style.name < $1.style.name }
        let byBrand = Dictionary(grouping: colors, by: { $0.info.brand })
        let byBrandAndTheme = byBrand.compactMap { key, value in
            let byTheme = Dictionary(grouping: value, by: { $0.info.systemTheme })
            return (key.lowercased(), byTheme)
        }
        brandColorsDictionary = Dictionary(uniqueKeysWithValues: byBrandAndTheme)

        fonts = file.styles.compactMap { (key: String, value: Style) -> FontStyle? in
            if let font = file.findFont(styleID: key) {
                return FontStyle(style: value, typeStyle: font)
            } else {
                return nil
            }
        }
        fonts.sort { $0.style.name < $1.style.name }

        regenerateTrimMap()
    }

    private func regenerateTrimMap() {
        guard colors != nil else {
            trimmedColorNamesCount = [:]
            return
        }

        var resultMap: [String: Int] = [:]
        for color in colors {
            let name = (colorPrefix + color.style.name.escaped.capitalizedFirstLetter).loweredFirstLetter.trimmingCharacters(in: .decimalDigits)
            resultMap[name] = (resultMap[name] ?? 0) + 1
        }

        trimmedColorNamesCount = resultMap
    }

    private func colorName(_ style: ColorStyle) -> String {
        let name = (colorPrefix + style.style.name.escaped.capitalizedFirstLetter).loweredFirstLetter
        guard trimEndingDigits == true else { return name }

        let trimmedName = name.trimmingCharacters(in: .decimalDigits)
        return trimmedColorNamesCount[trimmedName] == 1 ? trimmedName : name
    }

    private func fontName(_ style: FontStyle) -> String {
        let name = (style.style.name.escaped.capitalizedFirstLetter).loweredFirstLetter
        guard trimEndingDigits == true else { return name }

        let trimmedName = name.trimmingCharacters(in: .decimalDigits)
        return trimmedColorNamesCount[trimmedName] == 1 ? trimmedName : name
    }

    func generateIOSFonts(output: URL) throws {
        process()
        var strings: [String] = []
        strings.append(iOSSwiftFilePrefix)

        strings.append("public extension UIFont {")
        for font in fonts where font.style.styleType == .TEXT {
            strings.append("\(indent)// \(font.style.name)")
            strings.append("\(indent)static let \(fontName(font)) = \(font.typeStyle.uiFontSystem)")
        }
        strings.append("}\n")

        let text = strings.joined(separator: "\n")
        try save(text: text, to: output)
    }

    func generateIOS(homeDir: URL) throws {
        process()

        for brand in brandsToGenerate {
            let brandOutputFolder = brandsOutputFolder.replacingOccurrences(of: "@BRAND", with: brand)
            let brandThemeColors = brandColorsDictionary[brand] ?? [:]

            if source == "themes" {
                try generateThemeForBrand(brand, colors: brandThemeColors, brandOutputFolder: brandOutputFolder, homeDir: homeDir)
            } else if source == "gradients" {
                try generateGradientsForBrand(brand, colors: brandThemeColors, brandOutputFolder: brandOutputFolder, homeDir: homeDir)
            }
        }
    }

    private func generateThemeForBrand(_ brand: String, colors: BrandThemeColors, brandOutputFolder: String, homeDir: URL) throws {
        let brandOutputFolder = "\(brandOutputFolder)/Theme"
        let currentOutputFolder = "\(currentAppOutputFolder)/Theme"

        try generateLightTheme(with: colors, to: brandOutputFolder, homeDir: homeDir)
        try generateDarkTheme(with: colors, to: brandOutputFolder, homeDir: homeDir)
        try generateScheme(with: colors, to: brandOutputFolder, homeDir: homeDir)

        if brand == currentAppName {
            try generateLightTheme(with: colors, to: currentOutputFolder, homeDir: homeDir)
            try generateDarkTheme(with: colors, to: currentOutputFolder, homeDir: homeDir)
            try generateScheme(with: colors, to: currentOutputFolder, homeDir: homeDir)
        }
    }

    private func generateGradientsForBrand(_ brand: String, colors: BrandThemeColors, brandOutputFolder: String, homeDir: URL) throws {
        let brandOutputFile = "\(brandOutputFolder)/\(Constants.gradientsName)/\(Constants.gradientsName).swift"
        let currentOutputFile = "\(currentAppOutputFolder)/\(Constants.gradientsName)/\(Constants.gradientsName).swift"

        let output = brandOutputFile.absoluteFileURL(baseURL: homeDir)
        try generateGradients(with: colors, output: output)

        if brand == currentAppName {
            let output = currentOutputFile.absoluteFileURL(baseURL: homeDir)
            try generateGradients(with: colors, output: output)
        }
    }

    private func generateGradients(with colors: BrandThemeColors, output: URL) throws {
        print("Generate: \(output.path)")
        let dark = colors["Dark"]?.compactMap { $0.description.replacingOccurrences(of: "Gradient/", with: "").split(separator: ":") } ?? []
        let light = colors["Light"]?.compactMap { $0.description.replacingOccurrences(of: "Gradient/", with: "").split(separator: ":") } ?? []

        let darkDto = Dictionary(grouping: dark, by: { Int($0.first?.split(separator: "/").first ?? "0") })
        let lightDto = Dictionary(grouping: light, by: { Int($0.first?.split(separator: "/").first ?? "0") })

        var strings: [String] = []
        strings.append(iOSSwiftFilePrefix)

        let structName = output.deletingPathExtension().lastPathComponent.escaped.capitalizedFirstLetter
        strings.append("public class \(structName) {")
        strings.append("\(indent)public static var light: [GradientModel] = [")
        lightDto.forEach { dict in
            guard let id = dict.key,
                  let firstColor = dict.value.first(where: { $0.first?.contains("Start") ?? false })?.last?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let secondColor = dict.value.first(where: { $0.first?.contains("Middle") ?? false })?.last?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let thirdColor = dict.value.first(where: { $0.first?.contains("End") ?? false })?.last?.trimmingCharacters(in: .whitespacesAndNewlines)  else { return }
            strings.append("\(indent)\(indent).init(id: \"\(id)\", order: \(id), colors: [\"\(firstColor)\", \"\(secondColor)\", \"\(thirdColor)\"]),")
        }
        strings.append("\(indent)]")
        strings.append("")
        strings.append("\(indent)public static var dark: [GradientModel] = [")
        darkDto.forEach { dict in
            guard let id = dict.key,
                  let firstColor = dict.value.first(where: { $0.first?.contains("Start") ?? false })?.last?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let secondColor = dict.value.first(where: { $0.first?.contains("Middle") ?? false })?.last?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let thirdColor = dict.value.first(where: { $0.first?.contains("End") ?? false })?.last?.trimmingCharacters(in: .whitespacesAndNewlines)  else { return }
            strings.append("\(indent)\(indent).init(id: \"\(id)\", order: \(id), colors: [\"\(firstColor)\", \"\(secondColor)\", \"\(thirdColor)\"]),")
        }
        strings.append("\(indent)]")
        strings.append("}")
        strings.append("")

        strings.append("public class GradientModel {")
        strings.append("\(indent)public var id: String")
        strings.append("\(indent)public var order: Int")
        strings.append("\(indent)public var colors: [String]")
        strings.append("")
        strings.append("\(indent)public init(id: String, order: Int, colors: [String]) {")
        strings.append("\(indent)\(indent)self.id = id")
        strings.append("\(indent)\(indent)self.order = order")
        strings.append("\(indent)\(indent)self.colors = colors")
        strings.append("\(indent)}")
        strings.append("}")

        let text = strings.joined(separator: "\n")
        try save(text: text, to: output)
    }

    private func generateLightTheme(with brandThemeColors: BrandThemeColors, to folder: String, homeDir: URL) throws {
        let lightThemeFile = folder.appending("/Light\(Constants.schemeProtocolName).swift")
        let lightOutput = lightThemeFile.absoluteFileURL(baseURL: homeDir)
        let colors = brandThemeColors["Light"] ?? []
        try generateIOS(with: colors, output: lightOutput)
    }

    private func generateDarkTheme(with brandThemeColors: BrandThemeColors, to folder: String, homeDir: URL) throws {
        let darkThemeFile = folder.appending("/Dark\(Constants.schemeProtocolName).swift")
        let darkOutput = darkThemeFile.absoluteFileURL(baseURL: homeDir)
        let colors = brandThemeColors["Dark"] ?? []
        try generateIOS(with: colors, output: darkOutput)
    }

    private func generateScheme(with brandThemeColors: BrandThemeColors, to folder: String, homeDir: URL) throws {
        let schemeFile = folder.appending("/\(Constants.schemeProtocolName).swift")
        let schemeOutput = schemeFile.absoluteFileURL(baseURL: homeDir)
        try generateIOSSheme(with: brandThemeColors, output: schemeOutput)
    }

    private func generateIOS(with colors: [ColorStyle], output: URL) throws {
        print("Generate: \(output.path)")
        let parser = Parser(colors: colors)
        let uniqueColors = parser.getUniqueColors()
        let themeOptions = parser.getThemeOptions()
        let customThemeGroupedColors = parser.customThemeGroupedColors
        let baseColors = customThemeGroupedColors[nil] ?? []

        var strings: [String] = []
        strings.append(iOSSwiftFilePrefix)

        let structName = output.deletingPathExtension().lastPathComponent.escaped.capitalizedFirstLetter
        strings.append("public class \(structName)\(": \(Constants.schemeProtocolName)") {")
        strings.append("\(indent)public var \(Constants.optionsEnumName.loweredFirstLetter): \(Constants.optionsEnumName)\n")
        uniqueColors.forEach { color in
            strings.append("\(indent)public var \(colorName(color)) = UIColor()")
        }

        strings.append("")
        
        strings.append("\(indent)public init(with \(Constants.optionsEnumName.loweredFirstLetter): \(Constants.optionsEnumName)) {")
        strings.append("\(indent)\(indent)self.\(Constants.optionsEnumName.loweredFirstLetter) = \(Constants.optionsEnumName.loweredFirstLetter)")
        strings.append("\(indent)\(indent)switch \(Constants.optionsEnumName.loweredFirstLetter) {")
        themeOptions.forEach { option in
            strings.append("\(indent)\(indent)case .\(option.caseKey.lowercased()):")
            strings.append("\(indent)\(indent)\(indent) setup\(option.caseKey)\(Constants.optionsEnumName)()")
        }
        strings.append("\(indent)\(indent)}")
        strings.append("\(indent)\(indent)setupBaseColors()")
        strings.append("\(indent)}")
        strings.append("")

        strings.append("\(indent)private func setupBaseColors() {")
        baseColors.forEach { color in
            strings.append("\(indent)\(indent)\(colorName(color)) = \(useExtendedSRGBColorspace ? color.color.colorspaceUIColor : color.color.uiColor)")
        }
        strings.append("\(indent)}")
        strings.append("")

        themeOptions.forEach { option in
            let colors = customThemeGroupedColors[option.rawValue] ?? []
            generateSetupColorSchemeFunc(with: option.caseKey, colors: colors, strings: &strings)
            strings.append("")
        }
        
        strings.append("}")

        let text = strings.joined(separator: "\n")
        try save(text: text, to: output)
    }

    func generateIOSSheme(with brandThemeColors: BrandThemeColors, output: URL) throws {
        print("Generate: \(output.path)")

        let parser = Parser(colors: brandThemeColors)
        let uniqueColors = parser.getUniqueColors()
        let themeOptions = parser.getThemeOptions()

        var strings: [String] = []
        strings.append(iOSSwiftFilePrefix)
        
        strings.append("public enum \(Constants.optionsEnumName): String, CaseIterable {")
        themeOptions.forEach { key in
            strings.append("\(indent)case \(key.caseKey.lowercased()) = \"\(key.rawValue)\"")
        }
        strings.append("}\n")

        strings.append("public protocol \(Constants.schemeProtocolName) {")
        strings.append("\(indent)var \(Constants.optionsEnumName.loweredFirstLetter): \(Constants.optionsEnumName) { get }\n")
        for color in uniqueColors {
            strings.append("\(indent)/// \(color.style.name)")
            strings.append("\(indent)var \(colorName(color)): UIColor { get }")
        }
        strings.append("}\n")

        strings.append("public enum ColorName: String {")
        for color in uniqueColors {
            strings.append("\(indent)case \(colorName(color))")
        }
        strings.append("}\n")

        strings.append("extension \(Constants.schemeProtocolName) {")
        strings.append("\(indent)public subscript(colorName: ColorName) -> UIColor {")
        strings.append("\(indent)\(indent)switch colorName {")
        for color in uniqueColors {
            strings.append("\(indent)\(indent)case .\(colorName(color)): return \(colorName(color))")
        }
        strings.append("\(indent)\(indent)}")
        strings.append("\(indent)}")
        strings.append("}")

        let text = strings.joined(separator: "\n")
        try save(text: text, to: output)
    }

    private func generateSetupColorSchemeFunc(with option: String, colors: [ColorStyle], strings: inout [String]) {
        strings.append("\(indent)private func setup\(option)\(Constants.optionsEnumName)() {")
        colors.forEach { color in
            strings.append("\(indent)\(indent)\(colorName(color)) = \(useExtendedSRGBColorspace ? color.color.colorspaceUIColor : color.color.uiColor)")
        }
        strings.append("\(indent)}")
    }

    func generateAndroid(output: URL) throws {
        process()
        var strings: [String] = []

        strings.append(androidFilePrefix)
        for color in colors {
            strings.append("\(indent)<!--\(color.style.name)-->")
            strings.append("\(indent)<color name=\"\(colorName(color))\">\(color.color.androidHexColor)</color>")
        }
        strings.append(androidFileSuffix)

        let text = strings.joined(separator: "\n")
        try save(text: text, to: output)
    }

    private func save(text: String, to file: URL) throws {
        try? FileManager.default.removeItem(at: file)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try text.data(using: .utf8)?.write(to: file)
    }
}
