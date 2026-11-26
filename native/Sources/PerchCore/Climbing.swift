import Foundation

/// Where an agile pet (a red panda) is holding on to a window, relative to that window's bottom-left corner.
public enum ClingSide: String, Sendable { case front, left, right }

public struct Cling: Equatable, Sendable {
    public var window: UInt32
    public var offset: Point
    public var side: ClingSide
    /// Last movement direction, so sides know whether to draw the pet heading up or down.
    public var heading: Point
    var target: Point
    var until: Double
    /// Heading for the spot under the top edge where it will pull itself up.
    var exiting = false
    /// What to do on reaching the target, when what it's after is off this window.
    var then: ClingExit?
    /// Climbing speed: it scrambles when chasing.
    var pace = 1.0
}

/// At the end of a side or face: leap for what it's after, let go, or step down onto what's below.
enum ClingExit: Equatable, Sendable { case leap(Point), drop, dismount }

extension Surfaces {
    /// The window you'd see at `point`: windows arrive front to back.
    public static func frontmost(at point: Point, windows: [DesktopWindow]) -> DesktopWindow? {
        windows.first { $0.bounds.contains(point) }
    }
}

extension PetEngine {
    /// Points per art pixel.
    var artScale: Double { bodyHalfWidth / 16 }
    /// How high its torso is held when it first grips from standing, so its hind feet and tail stay near the
    /// ground; climbing poses are drawn about the torso.
    var clingLift: Double { bodyHalfWidth * 1.25 }

    /// The climbing pose for a grip: side on along a window's edge, and on its face by the way it's heading.
    public static func pose(for grip: Cling) -> SpecialPose {
        if grip.side != .front { return grip.heading.y >= 0 ? .scale : .scaleDown }
        let angle = atan2(abs(grip.heading.x), grip.heading.y) * 180 / .pi
        if angle <= 30 { return .crawl }
        // Steeply down, it backs down tail first, head up, rather than hanging upside down.
        if angle >= 135 { return .descend }
        return angle < 67.5 ? .slopeUp : angle <= 112.5 ? .traverse : .slopeDown
    }

    /// The stride frame to draw while climbing: from how far it has climbed, so paws stay planted, or the still
    /// frame while it holds on.
    public var strideFrame: Int {
        if climbHolding { return PixelSprites.stillFrame }
        return Int(strideProgress * 4) % 4
    }
    var strideProgress: Double {
        let p = (climbed / PixelSprites.strideLength).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }
    /// The body surges as each diagonal pair of paws pulls and eases as the next pair reaches; it averages 1.
    var strideSurge: Double { 1 - 0.6 * cos(4 * .pi * strideProgress) }

    /// One climbing step of up to `distance` points at `pace` points a second; returns how far it went. Backing
    /// down, the stride runs backwards.
    mutating func climbStep(_ distance: Double, pace: Double, dt: Double, backward: Bool = false) -> Double {
        let step = min(distance, pace * strideSurge * dt)
        climbed += (backward ? -step : step) / max(artScale, 0.01); climbHolding = step <= 0.01
        return step
    }

    /// Where its paw line would be for the pose it's gripping in: climbing poses are drawn about the torso (or,
    /// on a side, about the edge, with the body outside it).
    func standPoint(for grip: Cling) -> Point {
        let x = grip.side == .left ? -bodyHalfWidth * 0.4 : grip.side == .right ? bodyHalfWidth * 0.4 : 0
        return Point(position.x + x, position.y - bodyHalfWidth * 0.9)
    }
    /// Moves to that paw line, for letting go or leaping off.
    mutating func standFromGrip() {
        if let grip = cling { position = standPoint(for: grip) }
    }

    /// Grab the window face just below the edge underfoot, or the window right behind the pet.
    /// With a `goal`, only a face that the goal point is on, so it can climb toward the pointer.
    @discardableResult
    public mutating func startScramble(windows: [DesktopWindow], toward goal: Point? = nil) -> Bool {
        guard agile, state != .held else { return false }
        var options: [(DesktopWindow, Point)] = []
        if let s = support, s.kind == .window, let w = windows.first(where: { $0.id == s.windowID }),
           Surfaces.frontmost(at: Point(position.x, w.bounds.maxY - 12), windows: windows)?.id == w.id {
            // Over the top edge and down the face.
            options.append((w, Point(position.x - w.bounds.x, max(0, w.bounds.height - bodyHalfWidth * 1.2))))
        }
        if let w = Surfaces.frontmost(at: Point(position.x, position.y + 24), windows: windows), w.id != support?.windowID {
            options.append((w, Point(position.x - w.bounds.x, max(0, position.y + clingLift - w.bounds.y))))
        }
        if let goal {
            let over = Surfaces.frontmost(at: goal, windows: windows)?.id
            options.removeAll { $0.0.id != over }
        }
        guard !options.isEmpty else { return false }
        let (window, offset) = options[min(options.count - 1, Int(pick() * Double(options.count)))]
        endTrick()
        support = nil; velocity = Point(0, 0); climbTarget = nil
        lastClingOrigin = Point(window.bounds.x, window.bounds.y)
        var grip = Cling(window: window.id, offset: offset, side: .front, heading: Point(0, -1),
                         target: offset, until: clock + 8 + pick() * 8)
        grip.target = faceTarget(on: window, windows: windows) ?? offset
        grip.heading = Self.heading(from: grip.offset, to: grip.target) ?? grip.heading
        cling = grip; climbHolding = false
        change(.climb, .climb); trickPose = Self.pose(for: grip)
        nextScramble = clock + 6 + pick() * 8
        return true
    }

    static func heading(from a: Point, to b: Point) -> Point? {
        let d = hypot(b.x - a.x, b.y - a.y)
        return d > 0.5 ? Point((b.x - a.x) / d, (b.y - a.y) / d) : nil
    }

    /// Let go of the window face and drop to whatever is below.
    mutating func letGo(fling: Double = 0) {
        standFromGrip()
        fallFrom = cling?.window; fallGrab = nil; fallTime = 0
        cling = nil; lastClingOrigin = nil
        support = nil; velocity = Point(fling, 0); change(.fall, .fall)
    }

    /// A random spot on the window's visible face, as an offset from its bottom-left corner.
    mutating func faceTarget(on window: DesktopWindow, windows: [DesktopWindow]) -> Point? {
        for _ in 0..<8 {
            let a = pick(), b = pick()
            let x = 20 + a * max(0, window.bounds.width - 40)
            let y = bodyHalfWidth * 1.2 + b * max(0, window.bounds.height - bodyHalfWidth * 2.5)
            let point = Point(window.bounds.x + x, window.bounds.y + y)
            if Surfaces.frontmost(at: point, windows: windows)?.id == window.id { return Point(x, y) }
        }
        return nil
    }

    /// Climbing on a window face or side. The normal physics are skipped while it holds on.
    mutating func tendCling(dt: Double, surfaceDT: Double?, surfaces: [Surface], windows: [DesktopWindow],
                            restless: Bool) {
        guard var grip = cling, let window = windows.first(where: { $0.id == grip.window }) else { letGo(); return }
        let origin = Point(window.bounds.x, window.bounds.y)
        if let last = lastClingOrigin {
            let moved = hypot(origin.x - last.x, origin.y - last.y), interval = max(surfaceDT ?? dt, 0.001)
            // Sticky paws: it rides out a brisk drag and only lets go when the window is flung.
            if moved / interval > 1300 { letGo(fling: max(-220, min(220, (origin.x - last.x) / interval))); return }
        }
        lastClingOrigin = origin
        grip.offset.x = min(max(grip.offset.x, 0), window.bounds.width)
        grip.offset.y = min(max(grip.offset.y, 0), window.bounds.height)
        if (restless || clock > grip.until) && !grip.exiting {
            guard let exit = exitPoint(on: window, surfaces: surfaces, from: grip.offset) else { letGo(); return }
            grip.target = exit; grip.exiting = true
        }
        let dx = grip.target.x - grip.offset.x, dy = grip.target.y - grip.offset.y, distance = hypot(dx, dy)
        if distance > 0.5 {
            // Chasing the pointer, it scrambles; otherwise it climbs at a careful pace, surging with each pull.
            let pace = (grip.side == .front ? 28.0 : 36.0) * grip.pace
            grip.heading = Point(dx / distance, dy / distance)
            if grip.side != .front { grip.side = grip.offset.x <= 0.5 ? .left : grip.offset.x >= window.bounds.width - 0.5 ? .right : .front }
            let step = climbStep(distance, pace: pace, dt: dt, backward: PixelSprites.backsDown(Self.pose(for: grip)))
            grip.offset.x += dx / distance * step; grip.offset.y += dy / distance * step
            if abs(dx / distance) > 0.25 { direction = dx > 0 ? 1 : -1 }
        } else if grip.exiting {
            cling = grip
            mount(on: window, surfaces: surfaces, at: origin.x + min(max(grip.offset.x, 12), window.bounds.width - 12)); return
        } else if let then = grip.then {
            // At the edge nearest what it's after: off it goes.
            position = Point(origin.x + grip.offset.x, origin.y + grip.offset.y)
            cling = grip
            switch then {
            case .leap(let p):
                standFromGrip()
                leap(to: p, catching: Surfaces.frontmost(at: p, windows: windows)?.id)
            case .drop: letGo()
            case .dismount: dismount(surfaces: surfaces)
            }
            return
        } else if cursorPlay != nil {
            // Waiting where the pointer was, ready to grab it.
            climbHolding = true
        } else {
            climbHolding = true
            let roll = pick()
            if grip.side != .front, roll < 0.65 {
                // Holding a side: mostly keep climbing it, up or down a good stretch.
                let h = window.bounds.height, bw = bodyHalfWidth
                var y = bw + pick() * max(0, h - bw * 2)
                if abs(y - grip.offset.y) < bw * 2 { y = grip.offset.y > h / 2 ? bw : max(bw, h - bw) }
                grip.target = Point(grip.offset.x, y)
                grip.until = max(grip.until, clock + abs(y - grip.offset.y) / 36 + 3)
            } else if roll < 0.35, let next = faceTarget(on: window, windows: windows) {
                grip.target = next
            } else if roll < 0.65 {
                // Over to the nearer side, or along the side it's already on, with time to get there.
                let x = grip.side != .front ? grip.offset.x : grip.offset.x < window.bounds.width / 2 ? 0 : window.bounds.width
                let y = grip.offset.y + (pick() - 0.5) * 240
                grip.target = Point(x, min(max(y, bodyHalfWidth), max(bodyHalfWidth, window.bounds.height - bodyHalfWidth)))
                grip.until = max(grip.until, clock + hypot(grip.target.x - grip.offset.x, grip.target.y - grip.offset.y) / 28 + 6)
            } else if roll < 0.9, let exit = exitPoint(on: window, surfaces: surfaces, from: grip.offset) {
                grip.target = exit; grip.exiting = true
            } else {
                letGo(); return
            }
        }
        grip.side = grip.offset.x <= 0.5 ? .left : grip.offset.x >= window.bounds.width - 0.5 ? .right : .front
        // Side on to an edge, it faces the window: its body is outside it, its paws on the edge.
        if grip.side == .left { direction = 1 } else if grip.side == .right { direction = -1 }
        cling = grip
        position = Point(origin.x + grip.offset.x, origin.y + grip.offset.y)
        change(.climb, .climb)
        trickPose = Self.pose(for: grip)
    }

    /// At the bottom of a side it climbed down: step off onto the floor or ledge just below, or drop.
    mutating func dismount(surfaces: [Surface]) {
        guard let grip = cling else { return }
        let stand = standPoint(for: grip), side = grip.side, reach = bodyHalfWidth * 2.5
        let below = surfaces.filter {
            $0.kind != .menu && $0.supports(stand.x) && $0.y <= stand.y + 1 && $0.y >= stand.y - reach
        }.max { $0.y < $1.y }
        guard let below else { letGo(); return }
        cling = nil; lastClingOrigin = nil; climbHolding = false
        perch(on: below, x: stand.x)
        if side == .left { direction = -1 } else if side == .right { direction = 1 }
        change(.walk, .walk); nextChoice = 1.5 + pick() * 2; elapsed = 0
    }

    /// Where its torso stops coming down a side (screen y): just above the floor or ledge beside the window's
    /// bottom, or the bottom itself. Nil when that leaves no climb.
    func sideBottom(of window: DesktopWindow, side: Double, surfaces: [Surface]) -> Double? {
        let bw = bodyHalfWidth, b = window.bounds, outside = (side > 0 ? b.maxX : b.minX) + side * bw * 0.4
        let ground = surfaces.filter { $0.kind != .menu && $0.supports(outside) && $0.y < b.maxY - bw * 3 }.max { $0.y < $1.y }
        let bottom = max(b.minY, ground?.y ?? b.minY) + clingLift
        return bottom < b.maxY - bw * 2 ? bottom : nil
    }

    /// Back down a window's side, tail first, from the end of its top edge, then off onto what's below.
    @discardableResult
    mutating func startEdgeDescent(from window: DesktopWindow, toward side: Double, surfaces: [Surface],
                                   windows: [DesktopWindow]) -> Bool {
        let bw = bodyHalfWidth, b = window.bounds
        guard agile, b.height > bw * 4 else { return false }
        let x = side > 0 ? b.maxX : b.minX
        // Only from the window's real corner, right where it stands (a top edge can end short of it).
        guard abs(x - position.x) <= 16,
              Surfaces.frontmost(at: Point(x - side * 2, b.maxY - bw * 1.5), windows: windows)?.id == window.id,
              let bottom = sideBottom(of: window, side: side, surfaces: surfaces) else { return false }
        endTrick()
        support = nil; velocity = Point(0, 0); climbTarget = nil
        var grip = Cling(window: window.id, offset: Point(side > 0 ? b.width : 0, b.height - bw * 1.1),
                         side: side > 0 ? .right : .left, heading: Point(0, -1),
                         target: Point(side > 0 ? b.width : 0, bottom - b.y), until: clock + 30)
        grip.then = .dismount
        cling = grip; climbHolding = false; lastClingOrigin = Point(b.x, b.y)
        position = Point(x, b.y + grip.offset.y)
        direction = side > 0 ? -1 : 1
        change(.climb, .climb); trickPose = Self.pose(for: grip)
        return true
    }

    /// Just under the nearest uncovered stretch of the window's top edge, or nil if it's all covered. On a side
    /// whose top corner is clear, straight up the edge to that corner.
    func exitPoint(on window: DesktopWindow, surfaces: [Surface], from offset: Point) -> Point? {
        let x = window.bounds.x + offset.x
        let tops = surfaces.filter { $0.windowID == window.id && $0.kind == .window && $0.right - $0.left >= 30 }
        guard let top = tops.min(by: { abs(($0.left + $0.right) / 2 - x) < abs(($1.left + $1.right) / 2 - x) }) else { return nil }
        let y = window.bounds.height - bodyHalfWidth * 0.9
        let corner = offset.x <= 0.5 ? window.bounds.minX : offset.x >= window.bounds.width - 0.5 ? window.bounds.maxX : nil
        if let corner, top.supports(min(max(corner, window.bounds.minX + 12), window.bounds.maxX - 12)) {
            return Point(offset.x, y)
        }
        return Point(min(max(x, top.left + 12), top.right - 12) - window.bounds.x, y)
    }

    /// Pull itself up over the top edge: forepaws hooked on it, two little hauls, then the back paws up.
    mutating func mount(on window: DesktopWindow, surfaces: [Surface], at x: Double) {
        guard let top = surfaces.first(where: { $0.windowID == window.id && $0.kind == .window && $0.supports(x) }) else {
            letGo(); return
        }
        cling = nil; lastClingOrigin = nil; climbHolding = false
        position = Point(x, top.y - hangDepth - 1)
        beginClimb(to: top)
    }
}
