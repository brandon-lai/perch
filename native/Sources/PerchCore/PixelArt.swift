import Foundation

/// A small character grid. Each character is a palette slot; "." is transparent.
public struct PixelArt: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var cells: [Character]

    public init(width: Int = 32, height: Int = 32) {
        self.width = width; self.height = height
        cells = Array(repeating: ".", count: width * height)
    }
    public func contains(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }
    public subscript(x: Int, y: Int) -> Character {
        get { contains(x, y) ? cells[y * width + x] : "." }
        set {
            guard contains(x, y) else { assertionFailure("Pixel \(x),\(y) is outside \(width)×\(height)"); return }
            cells[y * width + x] = newValue
        }
    }
    mutating func run(_ y: Int, _ x0: Int, _ x1: Int, _ ch: Character) {
        guard x0 <= x1 else { return }
        for x in x0...x1 { self[x, y] = ch }
    }
    mutating func spans(_ ch: Character, _ table: KeyValuePairs<Int, (Int, Int)>) {
        for (y, span) in table { run(y, span.0, span.1, ch) }
    }
    mutating func dot(_ ch: Character, _ points: (Int, Int)...) {
        for p in points { self[p.0, p.1] = ch }
    }
    mutating func col(_ x: Int, _ y0: Int, _ y1: Int, _ ch: Character) {
        for y in y0...y1 { self[x, y] = ch }
    }
    mutating func over(_ other: PixelArt, mirror: Bool = false, flip: Bool = false,
                       dx: Int = 0, dy: Int = 0, remap: [Character: Character] = [:]) {
        for y in 0..<other.height {
            for x in 0..<other.width {
                let ch = other.cells[y * other.width + x]
                guard ch != "." else { continue }
                self[(mirror ? other.width - 1 - x : x) + dx, (flip ? other.height - 1 - y : y) + dy] = remap[ch] ?? ch
            }
        }
    }
}

public struct RGB: Hashable, Sendable {
    public var r: UInt8, g: UInt8, b: UInt8
    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) { self.r = r; self.g = g; self.b = b }
    public init(hex: String) {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0xC58B55
        self.init(UInt8((v >> 16) & 255), UInt8((v >> 8) & 255), UInt8(v & 255))
    }
    public var luminance: Double { (0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)) / 255 }
    var hsv: (h: Double, s: Double, v: Double) {
        let rf = Double(r) / 255, gf = Double(g) / 255, bf = Double(b) / 255
        let mx = max(rf, gf, bf), d = mx - min(rf, gf, bf)
        var h = 0.0
        if d > 0 {
            if mx == rf { h = (gf - bf) / d } else if mx == gf { h = (bf - rf) / d + 2 } else { h = (rf - gf) / d + 4 }
            h /= 6; if h < 0 { h += 1 }
        }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }
    init(h: Double, s: Double, v: Double) {
        let hue = (h.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let s = min(max(s, 0), 1), v = min(max(v, 0), 1)
        let f = hue - floor(hue), p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        let rgb = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)][Int(hue) % 6]
        self.init(UInt8((rgb.0 * 255).rounded()), UInt8((rgb.1 * 255).rounded()), UInt8((rgb.2 * 255).rounded()))
    }
    // Hue-shifted ramps: highlights drift warm, shadows drift toward red and gain saturation.
    func light() -> RGB { let c = hsv; return RGB(h: c.h + 0.012, s: c.s * 0.85, v: c.v + 0.11) }
    func shade() -> RGB { let c = hsv; return RGB(h: c.h - 0.015, s: c.s * 1.08 + 0.04, v: c.v * 0.8) }
    func far() -> RGB { let c = hsv; return RGB(h: c.h - 0.025, s: c.s * 1.12 + 0.06, v: c.v * 0.66) }
    func ink() -> RGB { let c = hsv; return RGB(h: c.h - 0.02, s: c.s * 0.7 + 0.12, v: min(0.3, c.v * 0.34)) }
    func softShade() -> RGB { let c = hsv; return RGB(h: c.h - 0.01, s: c.s * 1.1 + 0.05, v: c.v * 0.87) }
    func mixed(with other: RGB, _ t: Double) -> RGB {
        func mix(_ a: UInt8, _ b: UInt8) -> UInt8 { UInt8((Double(a) * (1 - t) + Double(b) * t).rounded()) }
        return RGB(mix(r, other.r), mix(g, other.g), mix(b, other.b))
    }
}

/// Resolves palette slots to colors and adds a one-pixel outline around the silhouette.
public struct PixelPalette: Sendable {
    public var colors: [Character: RGB]
    public var outline: RGB
    /// Outline used where the edge only touches light markings, so white paws keep a soft edge.
    public var softOutline: RGB
    public var softChars: Set<Character>
    /// Slots drawn after outlining and never outlined, such as whiskers or a flat rug.
    public var post: Set<Character>

    public init(colors: [Character: RGB], outline: RGB, softOutline: RGB? = nil,
                softChars: Set<Character> = [], post: Set<Character> = []) {
        self.colors = colors; self.outline = outline; self.softOutline = softOutline ?? outline
        self.softChars = softChars; self.post = post
    }

    public init(pack: PetPack) {
        let coat = RGB(hex: pack.coat), ear = RGB(hex: pack.earColor), mark = RGB(hex: pack.markingColor)
        let chest = pack.marking == .chest || pack.marking == .tuxedo
        let socks = pack.marking == .socks || pack.marking == .tuxedo
        let markShade = mark.softShade(), ink = coat.ink(), dark = coat.hsv.v < 0.38
        let colors: [Character: RGB] = [
            "h": coat.light(), "c": coat, "s": coat.shade(), "F": coat.far(),
            "e": ear, "d": ear.shade(), "f": ear.light(),
            "u": mark, "U": markShade,
            "w": chest ? mark : coat, "v": chest ? markShade : coat.shade(),
            "1": socks ? mark : coat, "2": socks ? markShade : coat.shade(), "z": socks ? markShade : coat.far(),
            "5": chest ? mark : coat,
            "o": ink, "k": RGB(hex: "#2B1F22"), "j": dark ? RGB(hex: "#8A5A36") : RGB(hex: "#2B1F22"),
            "i": RGB(hex: "#FFFAF0"), "q": RGB(hex: "#6E5D60"), "g": RGB(hex: "#A7C957"),
            "p": RGB(hex: "#E48C8C"), "P": RGB(hex: "#C46B70"), "m": RGB(hex: "#5A2E33"),
            "r": dark ? coat : coat.mixed(with: RGB(hex: "#F08C82"), 0.5),
            "b": RGB(hex: "#4B70C2"), "n": RGB(hex: "#34508F"), "y": RGB(hex: "#ECC65D"), "Y": RGB(hex: "#B88F36"),
            "x": RGB(hex: "#B9B3AB"), "H": RGB(hex: "#DF5A67"), "I": RGB(hex: "#F6B3BA"),
            "B": RGB(hex: "#E2654F"), "C": RGB(hex: "#F6B49F"),
            "L": RGB(hex: "#3F5F9F"), "M": RGB(hex: "#A8BBD8"), "N": RGB(hex: "#C98A52"), "R": RGB(hex: "#2F4677"),
        ]
        var soft = Set<Character>()
        if mark.luminance > coat.luminance + 0.15 {
            soft = Set(["w", "v", "u", "U", "1", "2", "5", "z"].filter { colors[$0] == mark || colors[$0] == markShade })
        }
        self.init(colors: colors, outline: ink, softOutline: markShade.mixed(with: ink, 0.45),
                  softChars: soft, post: ["x"])
    }

    /// Top-down RGBA bytes; every pixel is either fully opaque or fully transparent.
    public func rgba(_ art: PixelArt) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: art.width * art.height * 4)
        func put(_ x: Int, _ y: Int, _ c: RGB) {
            let i = (y * art.width + x) * 4
            out[i] = c.r; out[i + 1] = c.g; out[i + 2] = c.b; out[i + 3] = 255
        }
        func solid(_ x: Int, _ y: Int) -> Character? {
            let ch = art[x, y]
            return ch == "." || post.contains(ch) ? nil : ch
        }
        for y in 0..<art.height {
            for x in 0..<art.width {
                if let ch = solid(x, y) { put(x, y, colors[ch] ?? outline); continue }
                let near = [solid(x + 1, y), solid(x - 1, y), solid(x, y + 1), solid(x, y - 1)].compactMap { $0 }
                guard !near.isEmpty else { continue }
                put(x, y, near.allSatisfy { softChars.contains($0) } ? softOutline : outline)
            }
        }
        for y in 0..<art.height {
            for x in 0..<art.width where post.contains(art[x, y]) { put(x, y, colors[art[x, y]] ?? outline) }
        }
        return out
    }
}
