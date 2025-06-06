import Foundation

struct File: Codable {
    let name: String
    let version: String
    let document: Node

    let styles: [String: Style]
    let components: [String: Component]
}

struct Node: Codable {
    let id: String
    let name: String
    let type: NodeType

    let children: [Node]?

    let backgroundColor: Color?

    let style: TypeStyle?
    let styles: [String: String]?

    let fills: [Paint]?
    
    let componentId: String?
}

struct Color: Codable {
    let r: Double
    let g: Double
    let b: Double
    let a: Double
}

struct Style: Codable {
    let key: String
    let name: String
    let styleType: StyleType
    let description: String?
}

struct Component: Codable {
    let key: String
    let name: String
    let description: String?
}

struct TypeStyle: Codable {
    let fontFamily: String
    let fontWeight: Double
    let fontSize: Double
}

struct Paint: Codable {
    let type: PaintType
    let color: Color?
    let opacity: Double?
}

struct DownloadLinksInfo: Codable {
    let err: String?
    let images: [String: String?]
}

struct ColorInfo {
    var id: String = ""
    var brand: String = ""
    var systemTheme: String = ""
    var customTheme: String?
    var colorName: String = ""
}

struct Gradient {
    var id: String
    var name: String
    var colors: [GradientColor]
}

struct GradientColor {
    var id: String
    var color: Color?
}

struct OptionEnum {
    var caseKey: String
    var rawValue: String
}

typealias BrandColors = [String: BrandThemeColors]
typealias BrandThemeColors = [String: [ColorStyle]]
