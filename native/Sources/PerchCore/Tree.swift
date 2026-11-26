import Foundation

/// The red panda's tree. It stands on a display's floor wherever the owner puts it; the panda crawls up the
/// trunk, sits and grooms on the branch, and naps draped over it, as red pandas rest in trees.
public struct TreeHome: Equatable, Sendable {
    public let floor: Surface
    /// Bottom-left corner of the art, on the floor.
    public let origin: Point
    /// Points per art pixel, matching the panda so the tree shares its pixel grid.
    public let scale: Double

    /// `position` runs from 0 (left end of the floor) to 1 (right end).
    public init(floor: Surface, position: Double, scale: Double) {
        self.floor = floor; self.scale = scale
        let room = max(0, floor.right - floor.left - Double(PixelTree.width) * scale)
        origin = Point(floor.left + room * max(0, min(1, position.isFinite ? position : 0)), floor.y)
    }
    public var width: Double { Double(PixelTree.width) * scale }
    public var height: Double { Double(PixelTree.height) * scale }
    public var bounds: Rect { Rect(origin.x, origin.y, width, height) }
    /// Centre of the trunk, where the panda climbs.
    public var trunkX: Double { origin.x + PixelTree.trunkCenter * scale }
    /// The branch it rests on, from the trunk out to the leaves.
    public var branch: Surface {
        Surface(id: "tree-branch", left: origin.x + Double(PixelTree.branchFrom) * scale,
                right: origin.x + Double(PixelTree.branchTo + 1) * scale,
                y: origin.y + Double(PixelTree.height - PixelTree.branchTop) * scale, kind: .branch, origin: origin)
    }
    /// Where on the branch it settles: out from the trunk, clear of the leaves.
    public var restX: Double { origin.x + PixelTree.restX * scale }
    /// The 0–1 position that centres the tree under `x` on `floor`.
    public static func position(centeredAt x: Double, floor: Surface, scale: Double) -> Double {
        let width = Double(PixelTree.width) * scale, room = floor.right - floor.left - width
        guard room > 0 else { return 0 }
        return max(0, min(1, (x - width / 2 - floor.left) / room))
    }
}

public enum PixelTree {
    public static let width = 56, height = 72
    public static let trunkCenter = 22.0
    /// Top row of the branch, and the columns the panda can stand on.
    public static let branchTop = 41, branchFrom = 24, branchTo = 44
    public static let restX = 36.0

    /// A round-crowned tree: bark in three browns, leaves in clumps lit from the upper left, grass at its foot.
    public static func art() -> PixelArt {
        var g = PixelArt(width: width, height: height)
        for y in 30...70 {
            let flare = max(0, y - 63), a = 18 - flare, b = 25 + flare
            for x in a...b {
                let t = Double(x - a) / Double(max(1, b - a))
                g[x, y] = t < 0.12 || t > 0.88 ? "d" : t > 0.25 && t < 0.45 ? "B" : "b"
            }
            if y % 7 == 3 { g[21, y] = "d" }
            if y % 9 == 5 { g[23, y] = "k" }
        }
        for x in 26...47 { g[x, 41] = "B"; g[x, 42] = "b"; g[x, 43] = "d" }
        for x in stride(from: 30, through: 46, by: 5) { g[x, 41] = "k" }
        for (i, x) in (9...17).enumerated() { g[x, 33 - i / 3] = "b"; g[x, 34 - i / 3] = "d" }
        let clumps: [(Double, Double, Double)] = [(14, 19, 11), (28, 12, 12), (42, 18, 11), (21, 27, 9), (36, 28, 9),
                                                  (8, 28, 6), (49, 30, 6), (51, 40, 5), (46, 43, 4)]
        for y in 0..<height {
            for x in 0..<width {
                guard let (cx, cy, r) = clumps.first(where: { hypot(Double(x) + 0.5 - $0.0, Double(y) + 0.5 - $0.1) <= $0.2 }),
                      !(g[x, y] != "." && y >= 41 && x < 48) else { continue }
                let dx = (Double(x) + 0.5 - cx) / r, dy = (Double(y) + 0.5 - cy) / r
                var ch: Character = "G"
                if dy > 0.45 || (dx > 0.55 && dy > 0) { ch = "g" }
                if dy > 0.75 { ch = "s" }
                if dy < -0.35 && dx < 0.3 { ch = "l" }
                if dy < -0.6 && dx > -0.6 && dx < 0.1 { ch = "L" }
                g[x, y] = ch
            }
        }
        for x in 10...33 {
            let h = 1 + (x * 7) % 3
            for y in (70 - h)...70 where g[x, y] == "." { g[x, y] = y < 70 ? "r" : "G" }
            if x % 4 == 0, g[x, 69 - h] == "." { g[x, 69 - h] = "R" }
        }
        // Keep the outline's border free.
        for y in 0..<height { g[0, y] = "."; g[width - 1, y] = "." }
        for x in 0..<width { g[x, 0] = "."; g[x, height - 1] = "." }
        return g
    }

    public static let palette = PixelPalette(colors: [
        "d": RGB(hex: "#4A2C22"), "b": RGB(hex: "#6E4431"), "B": RGB(hex: "#8E5C3F"), "k": RGB(hex: "#B07A52"),
        "s": RGB(hex: "#25552F"), "g": RGB(hex: "#2F6B3A"), "G": RGB(hex: "#4E9A45"), "l": RGB(hex: "#79C058"),
        "L": RGB(hex: "#AEE17E"), "r": RGB(hex: "#5FA84A"), "R": RGB(hex: "#8FD06A"),
    ], outline: RGB(hex: "#22281D"))
}

public enum TreeActivity: Sendable { case exploring, goingToTree, inTree }

/// Where the old desktop home stood; read once to place the tree on the same side.
public enum HomeCorner: String, Codable, Sendable { case left, right }

/// Crawling up or down the trunk.
struct TreeClimb: Equatable, Sendable { var up: Bool }

extension PetEngine {
    /// Head for the tree to rest: when it's time to sleep, after a big meal, or just to visit.
    mutating func visitTree(for seconds: Double) {
        guard treeActivity == .exploring else { return }
        endTrick(); lounge = nil; errand = nil
        if cursorPlay != nil { endCursorPlay() }
        treeActivity = .goingToTree; treeVisitUntil = clock + seconds
    }

    /// Hugging the trunk, climbing up or backing down; the tree may be dragged meanwhile. Climbing poses are drawn about the torso,
    /// which runs from just above the ground to level with the branch. Returns true while it climbs.
    mutating func tendTreeClimb(_ tree: TreeHome, dt: Double, still: Bool) -> Bool {
        guard let climb = treeClimb else { return false }
        position.x = tree.trunkX; support = nil; velocity = Point(0, 0)
        let branch = tree.branch, low = tree.floor.y + clingLift, high = max(low, branch.y - bodyHalfWidth * 0.3)
        position.y = min(max(position.y, low), high)
        if climb.up {
            position.y = still ? high : position.y + climbStep(high - position.y, pace: 46, dt: dt)
            change(.climb, .climb); trickPose = .crawl
            if position.y >= high - 0.01 {
                treeClimb = nil; climbHolding = false; support = branch; position = Point(tree.restX, branch.y); direction = 1
                treeActivity = .inTree; change(.sit, .sit); nextChoice = 1 + pick() * 2
            }
        } else {
            position.y = still ? low : position.y - climbStep(position.y - low, pace: 52, dt: dt, backward: true)
            change(.climb, .climb); trickPose = .descend
            if position.y <= low + 0.01 {
                treeClimb = nil; climbHolding = false; support = tree.floor; position.y = tree.floor.y
                treeActivity = .exploring; change(.idle, .shake); actionRemaining = 0.6
            }
        }
        return true
    }

    /// On the way to the tree, or resting in it. Returns true when it used this tick.
    mutating func tendTree(_ tree: TreeHome, surfaces: [Surface], dt: Double, resting: Bool, still: Bool) -> Bool {
        guard let surface = support else { return false }
        // Petted or high-fived on the way (or up in the tree): enjoy it first.
        if state == .react && actionRemaining > 0 { return false }
        switch treeActivity {
        case .exploring:
            return false
        case .goingToTree:
            if surface.id == tree.branch.id { treeActivity = .inTree; return false }
            if surface.id == tree.floor.id, abs(position.x - tree.trunkX) < 2 || still {
                position.x = tree.trunkX
                treeClimb = TreeClimb(up: true)
                return tendTreeClimb(tree, dt: dt, still: still)
            }
            stepHome(to: tree.trunkX, floor: tree.floor, dt: dt, still: still)
            return true
        case .inTree:
            guard surface.id == tree.branch.id else { treeActivity = .exploring; return false }
            if resting {
                // Draped over the branch, legs dangling, the way red pandas sleep up high.
                change(.sleep, .sleep); trickPose = .drape
                return true
            }
            if clock >= treeVisitUntil {
                if state == .sleep { change(.idle, .stretch); actionRemaining = 1.5; return true }
                if state == .idle && action == .stretch && actionRemaining > 0 { return true }
                if abs(position.x - tree.trunkX) > 1 {
                    let toward: Double = tree.trunkX > position.x ? 1 : -1
                    direction = toward; change(.walk, .walk)
                    position.x += toward * min(abs(tree.trunkX - position.x), 30 * dt)
                    return true
                }
                treeClimb = TreeClimb(up: false)
                return tendTreeClimb(tree, dt: dt, still: still)
            }
            // A visit: settle on the branch, wash, snack, or doze.
            if elapsed >= nextChoice {
                let roll = pick()
                if roll < 0.3 { lounge = Lounge(pose: .groom, until: clock + 4 + pick() * 4) }
                else if roll < 0.5 { lounge = Lounge(pose: .nibble, until: clock + 5 + pick() * 4) }
                else if roll < 0.75 { change(.sleep, .sleep) } else { change(.sit, .sit) }
                elapsed = 0; nextChoice = 4 + pick() * 4
            }
            if let pose = lounge, clock < pose.until { trickPose = pose.pose; change(.idle, .sit) }
            else { lounge = nil; if state == .sleep { trickPose = .drape } }
            return true
        }
    }
}
