import Foundation

public enum HomeCorner: String, Codable, Sendable { case left, right }

public struct DesktopHome: Equatable, Sendable {
    /// Art pixels above the floor where a pet stands on the rug or curls into the cushion.
    public static let rugTop = Double(PixelHome.rugHeight)
    public static let cushionTop = 6.0
    public let screen: Rect
    public let floor: Surface
    public let origin: Point
    /// Points per art pixel, matching the pet's size so the furniture shares its pixel grid.
    public let scale: Double
    public init(screen: Rect, floor: Surface, corner: HomeCorner = .left, scale: Double = 3) {
        self.screen = screen
        self.floor = floor
        self.scale = scale
        let width = Double(PixelHome.width) * scale
        let x = corner == .left ? floor.left + 8 : floor.right - width - 8
        origin = Point(max(floor.left, x), floor.y)
    }
    public var width: Double { Double(PixelHome.width) * scale }
    public var pillowX: Double { origin.x + 19 * scale }
    public var bowlX: Double { origin.x + (Double(PixelHome.bowlX) + 7) * scale }
    /// Where a pet facing right stands so its nose reaches into the bowl.
    public var diningX: Double { origin.x + 37 * scale }
    public func onRug(_ x: Double) -> Bool { x >= origin.x && x <= origin.x + width }
}

/// The desktop home drawn in the same 32 px pixel language as the pet.
public enum PixelHome {
    public static let width = 64, height = 14, rugHeight = 2
    public static let bowlX = 46, bowlY = 2, bowlWidth = 14, bowlHeight = 10

    /// Flat stitched rug plus the round cushion. The bowl is separate so it can be a button.
    public static func base() -> PixelArt {
        var g = PixelArt(width: width, height: height)
        g.run(5, 7, 31, "a")
        g.run(6, 4, 34, "a"); g.run(6, 7, 31, "D")
        g.run(7, 3, 35, "a"); g.run(7, 6, 32, "D")
        g.run(8, 3, 35, "a"); g.run(9, 3, 35, "S"); g.run(10, 4, 34, "T")
        g.run(8, 6, 32, "A")
        for x in 0..<width { g[x, 12] = x % 3 == 1 ? "q" : "g"; g[x, 13] = "G" }
        return g
    }

    public static func bowl(full: Bool) -> PixelArt {
        var g = PixelArt(width: bowlWidth, height: bowlHeight)
        if full {
            g.run(1, 5, 8, "N"); g.run(2, 3, 10, "N"); g.dot("K", (5, 2), (8, 2), (6, 1))
        }
        g.run(3, 2, 11, "M")
        g.run(4, 1, 12, "M"); g.run(4, 2, 11, full ? "N" : "E")
        g.run(5, 1, 12, "L"); g.run(5, 3, 5, "Q")
        g.run(6, 1, 12, "L"); g.dot("Q", (3, 6))
        g.run(7, 2, 11, "L"); g.run(8, 3, 10, "R")
        return g
    }

    public static func palette(pressed: Bool = false) -> PixelPalette {
        PixelPalette(colors: [
            "a": RGB(hex: "#B4C5DF"), "A": RGB(hex: "#9DB2D2"), "D": RGB(hex: "#8EA5C8"),
            "S": RGB(hex: "#5F789F"), "T": RGB(hex: "#4D6489"),
            "g": RGB(hex: "#7488AB"), "G": RGB(hex: "#566A8F"), "q": RGB(hex: "#C7D3E6"),
            "M": RGB(hex: "#B4C5DF"), "E": RGB(hex: "#2F4677"), "L": RGB(hex: pressed ? "#344F83" : "#4265AC"),
            "Q": RGB(hex: pressed ? "#5E7DB8" : "#7F9FD6"), "R": RGB(hex: "#2F4677"),
            "N": RGB(hex: "#D39B64"), "K": RGB(hex: "#B27748"),
        ], outline: RGB(hex: "#2C3852"), post: ["g", "G", "q"])
    }
}

public struct PetCare: Codable, Equatable, Sendable {
    public static let mealInterval: TimeInterval = 15 * 60
    public private(set) var awakeSeconds = 0.0
    public private(set) var foodInBowl = false
    public var isHungry: Bool { awakeSeconds >= Self.mealInterval }
    public init() {}
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        awakeSeconds = try values.decode(Double.self, forKey: .awakeSeconds)
        guard (0...Self.mealInterval).contains(awakeSeconds) else {
            throw DecodingError.dataCorruptedError(forKey: .awakeSeconds, in: values, debugDescription: "Invalid active-time appetite.")
        }
        foodInBowl = try values.decode(Bool.self, forKey: .foodInBowl)
    }
    mutating func advance(_ seconds: Double) { awakeSeconds = min(Self.mealInterval, awakeSeconds + seconds) }
    mutating func fill() { foodInBowl = true }
    mutating func eat() { awakeSeconds = 0; foodInBowl = false }
}

public enum HomeActivity: Sendable {
    case exploring, goingToBowl, waiting, eating, goingToBed, napping
}
