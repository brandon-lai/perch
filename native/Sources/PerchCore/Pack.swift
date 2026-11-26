import Foundation

public enum Species: String, Codable, CaseIterable, Sendable {
    case dog, cat, redPanda
    public var displayName: String { self == .redPanda ? "Red panda" : rawValue.capitalized }
    /// Red pandas can grip any visible part of a window, not just its top edge.
    public var climbsWindows: Bool { self == .redPanda }
    /// A red panda's starting colors: warm orange coat, dark brown legs (the ear color), cream face mask.
    public static let redPandaColors = (coat: "#D9772E", ear: "#5A2F26", marking: "#F7EBD3")
    /// The first red panda colors, from before the pixel art followed the owner's references.
    static let firstRedPandaColors = (coat: "#C2532B", ear: "#3B2522", marking: "#F4EEE4")
}
public enum Marking: String, Codable, CaseIterable, Sendable { case none, chest, socks, tuxedo }
public enum Ears: String, Codable, CaseIterable, Sendable { case floppy, pointed }
public enum PetSize: String, Codable, CaseIterable, Sendable { case small, medium, large }
public enum Temperament: String, Codable, CaseIterable, Sendable { case calm, curious }
public enum LoopMode: String, Codable, Sendable { case loop, once, hold }
public enum Action: String, Codable, CaseIterable, Sendable {
    case idle, walk, sit, sleep, fall, ride, held, react, climb
    case pet, feed, play, sniff, stretch, yawn, shake, look, highFive, peek
}
public struct Anchor: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}
public struct Animation: Codable, Equatable, Sendable {
    public var name: Action
    public var frameCount: Int
    public var fps: Double
    public var loop: LoopMode
    public var anchor: Anchor
    public init(name: Action, frameCount: Int = 12, fps: Double = 12,
                loop: LoopMode = .loop, anchor: Anchor = .init(x: 0.5, y: 0)) {
        self.name = name; self.frameCount = frameCount; self.fps = fps
        self.loop = loop; self.anchor = anchor
    }
}
public enum PackError: LocalizedError, Equatable {
    case tooLarge, schema, rig, name, color, manifest, invalidAnimation
    public var errorDescription: String? {
        switch self {
        case .tooLarge: "Pack exceeds the 256 KiB limit."
        case .schema: "This pack schema is not supported. Use schemaVersion 1."
        case .rig: "This pack needs a different rig. Use perch-1."
        case .name: "Give your pet a name of 1–40 characters."
        case .color: "Coat, ear and marking colors must be #RRGGBB."
        case .manifest: "The pack must declare all 19 actions exactly once."
        case .invalidAnimation: "Animation frames, speed or paw anchors are out of bounds."
        }
    }
}
public struct PetPack: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var rigVersion = "perch-1"
    public var name: String
    public var species: Species
    public var coat: String
    public var earColor: String
    public var markingColor: String
    public var marking: Marking
    public var ears: Ears
    public var size: PetSize
    public var temperament: Temperament
    public var remembrance: Bool
    public var animations: [Animation]
    public init(name: String = "Milo", species: Species = .dog, coat: String = "#C58B55",
                earColor: String = "#875C43", markingColor: String = "#F2EDE4",
                marking: Marking = .chest, ears: Ears = .floppy, size: PetSize = .medium,
                temperament: Temperament = .curious, remembrance: Bool = false) {
        self.name = name; self.species = species; self.coat = coat; self.earColor = earColor
        self.markingColor = markingColor; self.marking = marking; self.ears = ears
        self.size = size; self.temperament = temperament; self.remembrance = remembrance
        animations = Action.allCases.map {
            Animation(name: $0, loop: [.sleep, .sit, .held].contains($0) ? .hold :
                [.pet, .feed, .play, .react, .stretch, .yawn, .shake, .highFive, .peek, .sniff].contains($0) ? .once : .loop)
        }
    }
    /// A red panda in its starting colors.
    public static func redPanda(name: String = "Maple", size: PetSize = .medium) -> PetPack {
        let colors = Species.redPandaColors
        return PetPack(name: name, species: .redPanda, coat: colors.coat, earColor: colors.ear, markingColor: colors.marking,
                       marking: .none, ears: .pointed, size: size)
    }
    /// Perch is all red panda: an older dog or cat pack keeps its name, size and temperament and becomes one,
    /// in red panda colors.
    public func asRedPanda() -> PetPack {
        guard species != .redPanda || ears != .pointed || marking != .none else { return self }
        var pack = self
        if species != .redPanda { (pack.coat, pack.earColor, pack.markingColor) = Species.redPandaColors }
        pack.species = .redPanda; pack.ears = .pointed; pack.marking = .none
        return pack
    }
    /// A red panda still wearing the first default colors moves to the current ones; edited colors are kept.
    public func withCurrentRedPandaColors() -> PetPack {
        let old = Species.firstRedPandaColors
        guard species == .redPanda, coat.uppercased() == old.coat, earColor.uppercased() == old.ear,
              markingColor.uppercased() == old.marking else { return self }
        var pack = self
        (pack.coat, pack.earColor, pack.markingColor) = Species.redPandaColors
        return pack
    }
    public func validated() throws -> PetPack {
        guard schemaVersion == 1 else { throw PackError.schema }
        guard rigVersion == "perch-1" else { throw PackError.rig }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(trimmed.count) else { throw PackError.name }
        for color in [coat, earColor, markingColor] {
            guard color.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else { throw PackError.color }
        }
        guard animations.count == Action.allCases.count,
              Set(animations.map(\.name)) == Set(Action.allCases) else { throw PackError.manifest }
        for animation in animations {
            guard (1...120).contains(animation.frameCount), animation.fps.isFinite,
                  (1...30).contains(animation.fps), animation.anchor.x.isFinite, animation.anchor.y.isFinite,
                  (0...1).contains(animation.anchor.x), (0...1).contains(animation.anchor.y) else {
                throw PackError.invalidAnimation
            }
        }
        var result = self
        result.name = trimmed
        return result
    }
    public static func decode(_ data: Data) throws -> PetPack {
        guard data.count <= 256 * 1024 else { throw PackError.tooLarge }
        return try JSONDecoder().decode(Self.self, from: data).validated()
    }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(validated())
        guard data.count <= 256 * 1024 else { throw PackError.tooLarge }
        return data
    }
}
