import ArgumentParser
import Foundation

private let launchURL = URL(fileURLWithPath: CommandLine.arguments[0])
private let homeDir = launchURL.deletingLastPathComponent()

struct FigmaGenerator: ParsableCommand {
    @Argument(help: "Figma file key")
    var figma_file_key: String
    
    @Option(name: [.customShort("a"), .customLong("token")], parsing: .next, help: "Figma personal access token")
    var personal_access_tokens: String?
    
    @Option(name: .customLong("android-output"), parsing: .next, help: "Andoid Output File")
    var andoid_output_file: String?
    
    @Option(name: .customLong("ios-output"), parsing: .next, help: "iOS Current App Output Folder")
    var ios_output_folder: String?

    @Option(name: .customLong("ios-brand-output"), parsing: .next, help: "iOS Brands Output Folder")
    var ios_brand_output_folder: String?

    @Option(name: .customLong("color-prefix"), parsing: .next, help: "Generated Color Prefix")
    var color_prefix: String?
    
    @Flag(name: .customLong("trim-ending"), help: "Trim ending digits")
    var trim_ending_digits: Bool = false
    
    @Flag(name: .customLong("use-srgb"), help: "Use extended sRGB color space (iOS)")
    var use_extended_srgb_colorspace: Bool = false
    
    @Option(name: .customLong("ios-icons-output"), parsing: .next, help: "iOS Icon Output Folder (.xcassets)")
    var ios_icons_output_folder: String?
    
    @Option(name: .customLong("ios-typo-output"), parsing: .next, help: "iOS Fonts Output File")
    var ios_typo_output: String?
    
    @Flag(name: .customLong("icons-template"), help: "Use icons as template")
    var icons_as_template: Bool = false
    
    @Option(name: .customLong("doc-paths"), parsing: .next, help: "Comma separated document related paths for parsing", transform: [String].csv)
    var doc_paths: [String]?
    
    @Flag(name: .customLong("drop-canva-name"), help: "Drop canva name in output")
    var drop_canva_name: Bool = false
    
    @Flag(name: .customLong("absolute-bounds"), help: "Use the full dimensions of the node regardless of whether or not it is cropped or the space around it is empty. Use this to export text nodes without cropping.")
    var use_absolute_bounds: Bool = false
    
    @Option(name: .customLong("cache-path"), parsing: .next, help: "Downloaded JSON cache path")
    var cache_path: String?

    @Option(name: .customLong("current-app-name"), parsing: .next, help: "Current App Name")
    var current_app_name: String?

    @Option(name: .customLong("source"), parsing: .next, help: "Themes or Gradients to generate")
    var source: String?

    @Option(name: .shortAndLong, parsing: .remaining, help: "Brands to generate")
    var brands: [String] = []

    func run() throws {
        let fileURL = URL(string: "https://api.figma.com/v1/files/\(figma_file_key)/")!
        let file: File = try URLSession.getData(at: fileURL, figmaToken: personal_access_tokens, cachePath: cache_path?.absoluteFileURL(baseURL: homeDir))

        let generator = StyleGenerator(file: file)
        generator.colorPrefix = color_prefix ?? ""
        generator.trimEndingDigits = trim_ending_digits
        generator.useExtendedSRGBColorspace = use_extended_srgb_colorspace

        if let file = andoid_output_file {
            let output = file.absoluteFileURL(baseURL: homeDir)
            try generator.generateAndroid(output: output)
            print("Generate: \(output.path)")
        }

        if let folder = ios_output_folder, let brandsFolder = ios_brand_output_folder, let currentAppName = current_app_name, let source = source {
            generator.currentAppOutputFolder = folder
            generator.currentAppName = currentAppName
            generator.brandsOutputFolder = brandsFolder
            generator.brandsToGenerate = brands
            generator.source = source
            try generator.generateIOS(homeDir: homeDir)
        }

        if let file = ios_typo_output {
            let output = file.absoluteFileURL(baseURL: homeDir)
            try generator.generateIOSFonts(output: output)
            print("Generate: \(output.path)")
        }
        
        if let folder = ios_icons_output_folder {
            let output = folder.absoluteFileURL(baseURL: homeDir)
            let downloaded = IconDownloader(file: file, fileKey: figma_file_key, accessToken: personal_access_tokens)
            downloaded.docPaths = doc_paths
            downloaded.dropCanvaName = drop_canva_name
            downloaded.iconsAsTemplate = icons_as_template
            downloaded.useAbsoluteBounds = use_absolute_bounds
            try downloaded.downloadPDFs(output: output)
        }
    }
}

FigmaGenerator.main()
