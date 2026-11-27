import Foundation

/// Where an agile pet (a red panda) is holding on: side on to a window's left or right edge, or hanging from its
/// bottom edge; or on its display's own frame, side on to the screen's left or right edge or hanging from the
/// top of the screen. It never climbs across a window's face.
public enum ClingSide: String, Sendable { case left, right, under, top }

public struct Cling: Equatable, Sendable {
    public var window: UInt32
    /// Relative to the window's bottom-left corner: on a side, (0 or width, torso height); hanging under it,
    /// (x, 0).
    public var offset: Point
    public var side: ClingSide
    /// Last movement direction: up or down a side, or along the bottom.
    public var heading: Point
    /// Where it's going, and on which edge; it goes round a bottom corner to reach another edge.
    var target: Point
    var targetSide: ClingSide
    var until: Double
    /// Heading up a side to its top corner, where it will pull itself up.
    var exiting = false
    /// What to do on reaching the target, when what it's after is off this window.
    var then: ClingExit?
    /// Climbing speed: it scrambles when chasing.
    var pace = 1.0
    /// On its display's frame rather than a window: the display's index. Offsets are then from the bottom-left of
    /// the area between the floor and the menu bar, and the panda is inside it.
    public var frame: Int?
    /// Gnawing the edge it holds until then.
    var gnawUntil: Double?

    init(window: UInt32, offset: Point, side: ClingSide, heading: Point, target: Point, until: Double,
         targetSide: ClingSide? = nil, frame: Int? = nil) {
        self.window = window; self.offset = offset; self.side = side; self.heading = heading
        self.target = target; self.targetSide = targetSide ?? side; self.until = until; self.frame = frame
    }
}

/// At the end of a climb: leap for what it's after (aiming its head at the pointer, or its paws at somewhere to
/// stand), let go, or step down onto what's below.
enum ClingExit: Equatable, Sendable { case leap(Point, head: Bool), drop, dismount }

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
    /// Hanging under a window, how far its torso is below the bottom edge.
    var underDrop: Double { PixelSprites.hangEdgeDrop * artScale }
    /// Torso height on a side at a bottom corner, where it swings under or back.
    var cornerHeight: Double { bodyHalfWidth * 0.4 }

    /// The climbing pose for a grip: side on to an edge, up it or backing down it, or hanging under a window.
    public static func pose(for grip: Cling) -> SpecialPose {
        if grip.gnawUntil != nil { return .gnaw }
        switch grip.side {
        case .left, .right: return grip.heading.y >= 0 ? .scale : .scaleDown
        case .under, .top: return .shimmy
        }
    }

    /// The stride frame to draw while climbing: from how far it has climbed, so paws stay planted, or the still
    /// frame while it holds on.
    public var strideFrame: Int {
        // Gnawing: chomp, chomp.
        if cling?.gnawUntil != nil { return Int(clock * 6) % 2 }
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

    /// Where it is on screen for a grip on a window at `origin`: on the edge it grips at torso height, or below
    /// the bottom edge it hangs from.
    func gripPoint(_ grip: Cling, origin: Point) -> Point {
        grip.side == .under ? Point(origin.x + grip.offset.x, origin.y - underDrop)
                            : Point(origin.x + grip.offset.x, origin.y + grip.offset.y)
    }

    /// Where its paw line would be for the pose it's gripping in, for letting go or leaping off.
    func standPoint(for grip: Cling) -> Point {
        // On a window its body is outside the edge; on the screen's frame it's inside.
        let outward = grip.frame == nil ? 1.0 : -1.0
        switch grip.side {
        case .left: return Point(position.x - outward * bodyHalfWidth * 0.4, position.y - bodyHalfWidth * 0.9)
        case .right: return Point(position.x + outward * bodyHalfWidth * 0.4, position.y - bodyHalfWidth * 0.9)
        case .under, .top: return Point(position.x, position.y - bodyHalfWidth * 0.9)
        }
    }
    /// Moves to that paw line, for letting go or leaping off.
    mutating func standFromGrip() {
        if let grip = cling { position = standPoint(for: grip) }
    }

    /// Onto a window's edges from wherever it is: down the side from the end of the top edge underfoot, up the
    /// side of a window beside it, or a leap up to hang from the bottom of a window above it.
    @discardableResult
    public mutating func startEdgeClimb(surfaces: [Surface], windows: [DesktopWindow]) -> Bool {
        guard agile, state != .held, let surface = support else { return false }
        let bw = bodyHalfWidth
        if surface.kind == .window, let w = windows.first(where: { $0.id == surface.windowID }) {
            for side in [-1.0, 1.0] where abs((side > 0 ? w.bounds.maxX : w.bounds.minX) - position.x) <= 16 {
                if startEdgeDescent(from: w, toward: side, surfaces: surfaces, windows: windows) { return true }
            }
        }
        // Beside the edge of the screen: up it.
        if let index = frameIndex(for: surface), let f = frameRect(index, surfaces: surfaces) {
            if position.x - f.minX < bw * 1.5, startFrameClimb(.left, surfaces: surfaces, toTop: pick() < 0.5) { return true }
            if f.maxX - position.x < bw * 1.5, startFrameClimb(.right, surfaces: surfaces, toTop: pick() < 0.5) { return true }
        }
        let near = windows.compactMap { w in climbableEdge(of: w, from: surface, windows: windows, within: bw * 3).map { (w, $0) } }
            .min { abs($0.1.stand - position.x) < abs($1.1.stand - position.x) }
        if let (w, edge) = near, abs(edge.stand - position.x) < 4 {
            return grabSide(of: w, facing: edge.facing, toTop: pick() < 0.5, surfaces: surfaces)
        }
        if let w = windows.first(where: {
            $0.bounds.minX + bw < position.x && position.x < $0.bounds.maxX - bw && $0.bounds.minY > position.y + bw * 2 &&
                $0.bounds.minY - position.y <= leapHeight && canHang(under: $0, surfaces: surfaces, windows: windows)
        }), clock >= nextLeap {
            leap(to: Point(position.x, w.bounds.minY - bw * 1.7), catching: w.id)
            return true
        }
        return false
    }

    static func heading(from a: Point, to b: Point) -> Point? {
        let d = hypot(b.x - a.x, b.y - a.y)
        return d > 0.5 ? Point((b.x - a.x) / d, (b.y - a.y) / d) : nil
    }

    /// Let go of the window and drop to whatever is below.
    mutating func letGo(fling: Double = 0) {
        standFromGrip()
        fallFrom = cling?.window; fallGrab = nil; fallTime = 0
        cling = nil; lastClingOrigin = nil; turnFrom = nil
        support = nil; velocity = Point(fling, 0); change(.fall, .fall)
    }

    /// Whether it can hang from this window's bottom edge: the edge is in view and there's room below for it.
    func canHang(under window: DesktopWindow, surfaces: [Surface], windows: [DesktopWindow]) -> Bool {
        let b = window.bounds
        guard b.width >= bodyHalfWidth * 3 else { return false }
        let ground = surfaces.filter { $0.kind != .menu && $0.supports(b.midX) && $0.y < b.minY }.map(\.y).max()
        guard let ground, b.minY - ground > bodyHalfWidth * 2.6 else { return false }
        return [b.minX + 4, b.midX, b.maxX - 4].allSatisfy {
            Surfaces.frontmost(at: Point($0, b.minY + 2), windows: windows)?.id == window.id
        }
    }

    /// Climbing a window's edges. The normal physics are skipped while it holds on.
    mutating func tendCling(dt: Double, surfaceDT: Double?, surfaces: [Surface], windows: [DesktopWindow],
                            restless: Bool) {
        if cling?.frame != nil { tendFrame(dt: dt, surfaces: surfaces, restless: restless); return }
        guard var grip = cling, let window = windows.first(where: { $0.id == grip.window }) else { letGo(); return }
        let b = window.bounds, origin = Point(b.x, b.y), bw = bodyHalfWidth
        if let last = lastClingOrigin {
            let moved = hypot(origin.x - last.x, origin.y - last.y), interval = max(surfaceDT ?? dt, 0.001)
            // Sticky paws: it rides out a brisk drag and only lets go when the window is flung.
            if moved / interval > 1300 { letGo(fling: max(-220, min(220, (origin.x - last.x) / interval))); return }
        }
        lastClingOrigin = origin
        // Its edge may have moved or resized under it.
        switch grip.side {
        case .left: grip.offset = Point(0, min(max(grip.offset.y, cornerHeight), b.height))
        case .right: grip.offset = Point(b.width, min(max(grip.offset.y, cornerHeight), b.height))
        case .under, .top: grip.offset = Point(min(max(grip.offset.x, 0), b.width), 0)
        }
        if let until = grip.gnawUntil {
            // Gnawing the edge it holds; done (or interrupted), it leaves a nibble there.
            if restless || cursorPlay != nil || clock >= until {
                grip.gnawUntil = nil
                // The mark is 11 art pixels long; keep it whole on the side, even gnawing right by the top corner.
                let margin = PixelSprites.biteMarkHalfLength * artScale
                if clock >= until, mischief.chew, grip.side == .left || grip.side == .right, b.height >= 2 * margin {
                    let mouth = min(max(grip.offset.y + 13 * artScale, margin), b.height - margin)
                    events.append(.bite(window: grip.window, edge: grip.side == .left ? .left : .right, offset: mouth))
                }
                nextChew = clock + 20 + pick() * 25
            } else {
                climbHolding = true; cling = grip
                position = gripPoint(grip, origin: origin); change(.climb, .climb); trickPose = .gnaw
                return
            }
        }
        if grip.side == .under || grip.targetSide == .under, !canHang(under: window, surfaces: surfaces, windows: windows) {
            if grip.side == .under { letGo(); return }
            grip.targetSide = grip.side; grip.target = Point(grip.offset.x, cornerHeight)
        }
        if (restless || clock > grip.until) && !grip.exiting && grip.then != .dismount {
            // Time to get off: over the top, down to the ground beside it, or just let go.
            if let exit = exitPoint(on: window, surfaces: surfaces, from: grip) {
                grip.targetSide = exit.side; grip.target = exit.point; grip.exiting = true; grip.then = nil
            } else if grip.side != .under, let bottom = landingBottom(of: window, side: grip.side, surfaces: surfaces) {
                grip.targetSide = grip.side; grip.target = Point(grip.offset.x, bottom - b.y); grip.then = .dismount
                grip.until = clock + 60
            } else { letGo(); return }
        }
        // The next stop on this edge: the target, or the bottom corner on the way round to another edge.
        var stop = grip.target, turn: (ClingSide, Point)?
        if grip.targetSide != grip.side {
            switch grip.side {
            case .left, .right:
                stop = Point(grip.offset.x, cornerHeight)
                turn = (.under, Point(grip.side == .left ? 0 : b.width, 0))
            case .under, .top:
                let to: ClingSide = grip.targetSide == .under ? .left : grip.targetSide
                stop = Point(to == .left ? 0 : b.width, 0)
                turn = (to, Point(to == .left ? 0 : b.width, cornerHeight))
            }
        }
        let dx = stop.x - grip.offset.x, dy = stop.y - grip.offset.y, distance = hypot(dx, dy)
        if distance > 0.5 {
            // Chasing the pointer, it scrambles; otherwise it climbs at a careful pace, surging with each pull.
            let pace = (grip.side == .under ? 30.0 : 36.0) * grip.pace
            grip.heading = Point(dx / distance, dy / distance)
            let step = climbStep(distance, pace: pace, dt: dt, backward: PixelSprites.backsDown(Self.pose(for: grip)))
            grip.offset.x += dx / distance * step; grip.offset.y += dy / distance * step
        } else if let (side, offset) = turn {
            // Round the bottom corner: it swings from the side to hanging underneath, or back up.
            turnFrom = (gripPoint(grip, origin: origin), clock)
            grip.side = side; grip.offset = offset
            grip.heading = side == .under ? Point(offset.x <= 0.5 ? 1 : -1, 0) : Point(0, 1)
        } else if grip.exiting {
            cling = grip
            let x = grip.side == .left ? b.minX + 2 : b.maxX - 2
            mount(on: window, surfaces: surfaces, at: x); return
        } else if let then = grip.then {
            // At the edge nearest what it's after: off it goes.
            position = gripPoint(grip, origin: origin)
            cling = grip
            switch then {
            case .leap(let p, let head):
                // Off the edge with its head aimed at the pointer, or its paws at where it means to stand.
                standFromGrip()
                leap(to: head ? Point(p.x, p.y - bodyHalfWidth * 1.7) : p, catching: nil)
            case .drop: letGo()
            case .dismount: dismount(surfaces: surfaces, windows: windows)
            }
            if let still = cling {
                // Still holding on (nothing to step onto, so it's going under instead): draw it as such.
                position = gripPoint(still, origin: origin)
                change(.climb, .climb); trickPose = Self.pose(for: still)
            }
            return
        } else if cursorPlay != nil {
            // Waiting where the pointer was, ready to grab it.
            climbHolding = true
        } else {
            climbHolding = true
            wanderEdges(&grip, window: window, surfaces: surfaces, windows: windows)
            if cling == nil { return }
        }
        switch grip.side {
        case .left: direction = 1
        case .right: direction = -1
        case .under, .top: if abs(grip.heading.x) > 0.1 { direction = grip.heading.x > 0 ? 1 : -1 }
        }
        cling = grip
        position = gripPoint(grip, origin: origin)
        if let turn = turnFrom {
            // Ease through the corner rather than jumping.
            let t = min(1, (clock - turn.at) / 0.3)
            if t >= 1 { turnFrom = nil } else {
                let e = t * t * (3 - 2 * t)
                position = Point(turn.from.x + (position.x - turn.from.x) * e, turn.from.y + (position.y - turn.from.y) * e)
            }
        }
        change(.climb, .climb)
        trickPose = Self.pose(for: grip)
    }

    /// Somewhere new along the window's edges, once it has got where it was going.
    private mutating func wanderEdges(_ grip: inout Cling, window: DesktopWindow, surfaces: [Surface], windows: [DesktopWindow]) {
        let b = window.bounds, bw = bodyHalfWidth, roll = pick()
        let hang = canHang(under: window, surfaces: surfaces, windows: windows)
        grip.then = nil
        switch grip.side {
        case .left, .right:
            if mischief.chew && !gentle && clock >= nextChew && pick() < 0.45 {
                // A gnaw at the edge it's holding, where it leaves a nibble.
                grip.gnawUntil = clock + 2.2 + pick() * 1.2
            } else if roll < 0.45 {
                // Up or down a good stretch of this side.
                var y = bw + pick() * max(0, b.height - bw * 2)
                if abs(y - grip.offset.y) < bw * 2 { y = grip.offset.y > b.height / 2 ? bw : max(bw, b.height - bw) }
                grip.target = Point(grip.offset.x, y)
                grip.until = max(grip.until, clock + abs(y - grip.offset.y) / 36 + 3)
            } else if roll < 0.7, let exit = exitPoint(on: window, surfaces: surfaces, from: grip) {
                grip.targetSide = exit.side; grip.target = exit.point; grip.exiting = true
            } else if roll < 0.85, hang {
                // Down and round the corner to hang along the bottom.
                grip.targetSide = .under; grip.target = Point(bw + pick() * max(0, b.width - bw * 2), 0)
                grip.until = max(grip.until, clock + (grip.offset.y + b.width) / 30 + 6)
            } else if let bottom = sideBottom(of: window, side: grip.side == .right ? 1 : -1, surfaces: surfaces) {
                grip.target = Point(grip.offset.x, bottom - b.y); grip.then = .dismount
                grip.until = max(grip.until, clock + grip.offset.y / 36 + 6)
            } else { letGo() }
        case .under, .top:
            if roll < 0.45 {
                var x = bw + pick() * max(0, b.width - bw * 2)
                if abs(x - grip.offset.x) < bw * 2 { x = grip.offset.x > b.width / 2 ? bw : max(bw, b.width - bw) }
                grip.target = Point(x, 0)
                grip.until = max(grip.until, clock + abs(x - grip.offset.x) / 30 + 3)
            } else if roll < 0.8 {
                // Round a corner and up that side.
                let side: ClingSide = grip.offset.x < b.width / 2 ? .left : .right
                grip.targetSide = side
                grip.target = Point(side == .left ? 0 : b.width, bw + pick() * max(0, b.height - bw * 2))
                grip.until = max(grip.until, clock + (b.width / 2 + b.height) / 30 + 6)
            } else { letGo() }
        }
    }

    /// At the bottom of a side it climbed down: step off onto the floor or ledge just below. With nothing close
    /// below, it goes round the corner to hang underneath if it can, or drops.
    mutating func dismount(surfaces: [Surface], windows: [DesktopWindow]) {
        guard var grip = cling else { return }
        let stand = standPoint(for: grip), side = grip.side, reach = bodyHalfWidth * 2.5
        let below = surfaces.filter {
            $0.kind != .menu && $0.supports(stand.x) && $0.y <= stand.y + 1 && $0.y >= stand.y - reach
        }.max { $0.y < $1.y }
        guard let below else {
            if grip.side != .under, let w = windows.first(where: { $0.id == grip.window }),
               canHang(under: w, surfaces: surfaces, windows: windows) {
                grip.then = nil; grip.targetSide = .under
                grip.target = Point(bodyHalfWidth + pick() * max(0, w.bounds.width - bodyHalfWidth * 2), 0)
                grip.until = clock + 20
                cling = grip
                return
            }
            letGo(); return
        }
        cling = nil; lastClingOrigin = nil; climbHolding = false; turnFrom = nil
        perch(on: below, x: stand.x)
        if side == .left { direction = -1 } else if side == .right { direction = 1 }
        change(.walk, .walk); nextChoice = 1.5 + pick() * 2; elapsed = 0
    }

    /// Where its torso stops coming down a side to step off onto the floor or a ledge beside it (screen y), or nil
    /// when there's nothing there close enough to step onto.
    func landingBottom(of window: DesktopWindow, side: ClingSide, surfaces: [Surface]) -> Double? {
        guard side != .under, let bottom = sideBottom(of: window, side: side == .right ? 1 : -1, surfaces: surfaces) else { return nil }
        let x = (side == .right ? window.bounds.maxX : window.bounds.minX) + (side == .right ? 1 : -1) * bodyHalfWidth * 0.4
        let stand = bottom - bodyHalfWidth * 0.9
        let ground = surfaces.contains {
            $0.kind != .menu && $0.supports(x) && $0.y <= stand + 1 && $0.y >= stand - bodyHalfWidth * 2.5
        }
        return ground ? bottom : nil
    }

    /// Where its torso stops coming down a side (screen y): just above the floor or ledge beside the window's
    /// bottom, or the bottom corner. Nil when that leaves no climb.
    func sideBottom(of window: DesktopWindow, side: Double, surfaces: [Surface]) -> Double? {
        let bw = bodyHalfWidth, b = window.bounds, outside = (side > 0 ? b.maxX : b.minX) + side * bw * 0.4
        let ground = surfaces.filter { $0.kind != .menu && $0.supports(outside) && $0.y < b.maxY - bw * 3 }.max { $0.y < $1.y }
        let bottom = max(b.minY + cornerHeight, (ground?.y ?? b.minY) + clingLift)
        return bottom < b.maxY - bw * 2 ? bottom : nil
    }

    /// Back down a window's side, side on, from the end of its top edge, then off onto what's below.
    @discardableResult
    public mutating func startEdgeDescent(from window: DesktopWindow, toward side: Double, surfaces: [Surface],
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
        cling = grip; climbHolding = false; lastClingOrigin = Point(b.x, b.y); turnFrom = nil
        position = Point(x, b.y + grip.offset.y)
        direction = side > 0 ? -1 : 1
        change(.climb, .climb); trickPose = Self.pose(for: grip)
        return true
    }

    /// Up a side to a top corner that's clear to pull itself over: this side's, or from under the window the
    /// nearer side's. Nil when neither top corner is clear.
    func exitPoint(on window: DesktopWindow, surfaces: [Surface], from grip: Cling) -> (side: ClingSide, point: Point)? {
        let b = window.bounds
        let tops = surfaces.filter { $0.windowID == window.id && $0.kind == .window && $0.right - $0.left >= 30 }
        func clear(_ side: ClingSide) -> Bool {
            let x = side == .left ? b.minX + 12 : b.maxX - 12
            return tops.contains { $0.supports(x) }
        }
        var sides: [ClingSide]
        switch grip.side {
        case .left: sides = [.left]
        case .right: sides = [.right]
        case .under, .top: sides = grip.offset.x < b.width / 2 ? [.left, .right] : [.right, .left]
        }
        guard let side = sides.first(where: clear) else { return nil }
        return (side, Point(side == .left ? 0 : b.width, b.height - bodyHalfWidth * 0.9))
    }

    /// Pull itself up over the top corner: forepaws hooked on it, two little hauls, then the back paws up.
    mutating func mount(on window: DesktopWindow, surfaces: [Surface], at x: Double) {
        guard let top = surfaces.first(where: { $0.windowID == window.id && $0.kind == .window && $0.supports(x, margin: -14) })
        else { letGo(); return }
        cling = nil; lastClingOrigin = nil; climbHolding = false; turnFrom = nil
        position = Point(min(max(x, top.left), top.right), top.y - hangDepth - 1)
        beginClimb(to: top)
    }
}
