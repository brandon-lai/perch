import Foundation

/// Red panda cursor play: notice the pointer anywhere on its display, go after it (along ledges, up window sides,
/// with leaps), rear up and swipe, then dangle from it chewing. Only the pointer's current position and a
/// smoothed velocity are used; nothing is recorded.
public struct CursorPlay: Equatable, Sendable {
    enum Phase: Equatable, Sendable { case notice(until: Double), stalk, swipe(until: Double), hang(until: Double) }
    var phase: Phase
    var until: Double
    /// Going after the pointer: noticed it, or on its way.
    var chasing: Bool {
        switch phase {
        case .notice, .stalk: return true
        case .swipe, .hang: return false
        }
    }
}

/// A held, research-based pose: washing its face, nibbling an apple, or rearing up with arms high.
struct Lounge: Equatable, Sendable {
    var pose: SpecialPose
    var until: Double
}

/// Somewhere it has decided to explore: a window's top edge, across the floor, or up the side of a window from
/// beside it.
struct Errand: Equatable, Sendable {
    var target: Point
    var until: Double
    var edge: EdgeGrip?
}

/// A window side to climb: the panda stands just outside it (facing the window) and grips the edge.
struct EdgeGrip: Equatable, Sendable {
    var window: UInt32
    var facing: Double
    /// Where it stands to grab on.
    var stand: Double
}

extension PetEngine {
    /// Dangling from the pointer. The app makes the pet click-through while this is true.
    public var holdingCursor: Bool { if case .hang = cursorPlay?.phase { return true }; return false }

    /// How far below the pointer the paw line sits while dangling, in points.
    var hangDrop: Double {
        bodyHalfWidth * 2 * (Double(PixelSprites.side - PixelSprites.hangGripRow) - 0.5) / Double(PixelSprites.side)
    }

    /// How high it can leap: a bit over three times its own height.
    var leapHeight: Double { bodyHalfWidth * 2 * 3.4 }

    /// Where its forepaws reach when it rears up, or where its head is while it climbs.
    var reachPoint: Point {
        let pose: SpecialPose? = cling.map { Self.pose(for: $0) } ?? treeClimb.map { $0.up ? .scale : .scaleDown }
        if let pose, let head = PixelSprites.climbHead(pose) {
            return Point(position.x + head.x * artScale * direction, position.y + head.y * artScale)
        }
        return Point(position.x, position.y + bodyHalfWidth * 1.7)
    }

    mutating func trackCursor(_ cursor: Point?, dt: Double) {
        guard let cursor else { lastCursor = nil; cursorVelocity = Point(0, 0); return }
        if let last = lastCursor {
            guard dt >= 0.004 else { return }
            let v = Point((cursor.x - last.x) / dt, (cursor.y - last.y) / dt)
            cursorVelocity = Point(cursorVelocity.x * 0.4 + v.x * 0.6, cursorVelocity.y * 0.4 + v.y * 0.6)
        } else { cursorVelocity = Point(0, 0) }
        lastCursor = cursor
    }

    func screen(of point: Point, in screens: [Rect]) -> Rect? {
        screens.first { $0.contains(point) } ?? screens.min {
            hypot($0.midX - point.x, $0.midY - point.y) < hypot($1.midX - point.x, $1.midY - point.y)
        }
    }

    /// Anywhere on its display, the pointer is irresistible; one whizzing right past makes it rear up.
    mutating func noticeCursor(_ cursor: Point?, screens: [Rect], dt: Double) -> Bool {
        guard agile, mischief.cursor, !gentle, cursorPlay == nil, let cursor, support != nil || cling != nil, trick == nil,
              climbTarget == nil, treeClimb == nil, treeActivity == .exploring, state != .sleep,
              lounge?.pose != .grab else { return false }
        let center = Point(position.x, position.y + bodyHalfWidth)
        let distance = hypot(cursor.x - center.x, cursor.y - center.y)
        let speed = hypot(cursorVelocity.x, cursorVelocity.y)
        if support != nil, distance < bodyHalfWidth * 2.5, speed > 1400, clock >= nextStartle {
            // The defensive stance: up on its hind legs, forepaws high and spread, then back to whatever it was doing.
            lounge = Lounge(pose: .grab, until: clock + 0.8 + pick() * 0.6); nextStartle = clock + 20
            direction = cursor.x >= position.x ? 1 : -1
            change(.idle, .look)
            return true
        }
        // Not when the pointer rests on the pet itself (someone about to pet or pick it up), not for a nibbled-down
        // stalk, and only on its own display.
        guard clock >= nextCursorPlay, !bambooPointer || bamboo >= 0.6, distance > bodyHalfWidth * 0.9,
              let here = screen(of: position, in: screens), here.contains(cursor), pick() < dt * 2.5 else { return false }
        lounge = nil; errand = nil
        cursorPlay = CursorPlay(phase: .notice(until: clock + 0.3 + pick() * 0.4), until: clock + 25)
        direction = cursor.x >= position.x ? 1 : -1
        change(.idle, .look)
        return true
    }

    /// Stop chasing. A chase that never reached the pointer counts as a miss; a couple in a row and it explores a while.
    mutating func endCursorPlay(missed: Bool = false) {
        if holdingCursor { dropFromCursor(); return }
        if cursorPlay != nil {
            if missed { chaseMisses += 1 }
            nextCursorPlay = clock + (chaseMisses >= 2 ? 10 : 2) + pick() * 3
            if chaseMisses >= 2 { chaseMisses = 0 }
        }
        cursorPlay = nil
    }

    mutating func grabCursor(_ cursor: Point) {
        // A bamboo stalk keeps it busy until it's eaten; a bare pointer only for a while.
        cursorPlay = CursorPlay(phase: .hang(until: clock + (bambooPointer ? 30 : 6 + pick() * 10)), until: clock + 40)
        support = nil; cling = nil; lastClingOrigin = nil; climbTarget = nil; lounge = nil; errand = nil; endTrick()
        leaping = false; leapCatch = nil; chaseMisses = 0
        // From where its mouth is now; the hang pose is anchored at its teeth.
        velocity = Point(0, 0); position = Point(position.x, position.y + hangDrop); leapUntil = clock + 0.25
        hangSwing = 0; swingRate = direction * 1.5; shakeTimes = []
        trickPose = .hang; change(.react, .held)
    }

    /// Dangling from the pointer and gnawing it. A real shake, a hard fling, boredom or bedtime drops it.
    mutating func tendHang(_ cursor: Point?, dt: Double, restless: Bool) {
        guard case .hang(let until) = cursorPlay?.phase, let cursor else { dropFromCursor(); return }
        let vx = cursorVelocity.x, speed = hypot(cursorVelocity.x, cursorVelocity.y)
        if abs(vx) > 700 {
            let sign: Double = vx > 0 ? 1 : -1
            if sign != shakeSign { shakeSign = sign; shakeTimes.append(clock) }
        }
        shakeTimes.removeAll { clock - $0 > 0.9 }
        // Sticky: ordinary pointing and dragging keep it on. Three quick reversals shake it loose.
        if shakeTimes.count >= 4 || speed > 4200 || clock > until || restless {
            let shaken = shakeTimes.count >= 4 || speed > 4200
            dropFromCursor(fling: Point(cursorVelocity.x * 0.15, cursorVelocity.y * 0.15))
            if shaken { nextCursorPlay = clock + 6 + pick() * 4 }
            return
        }
        if bambooPointer {
            // About ten seconds of munching for a whole stalk; then down it hops, content, and maybe off for a nap.
            bamboo = max(0, bamboo - dt / 10)
            if bamboo == 0 {
                sated = true; dropFromCursor(); nextCursorPlay = clock + 20
                if pick() < 0.4 { visitTree(for: 15 + pick() * 15) }
                return
            }
        }
        if clock < leapUntil {
            let follow = min(1, dt * 18)
            position = Point(position.x + (cursor.x - position.x) * follow, position.y + (cursor.y - position.y) * follow)
        } else { position = cursor }
        // A damped pendulum: it trails behind the pointer and swings back past it.
        let target = max(-0.5, min(0.5, -vx / 2400))
        swingRate += (-(hangSwing - target) * 60 - swingRate * 5) * dt
        hangSwing = max(-0.7, min(0.7, hangSwing + swingRate * dt))
        if abs(vx) > 40 { direction = vx > 0 ? 1 : -1 }
        trickPose = .hang; change(.react, .held)
    }

    mutating func dropFromCursor(fling: Point = Point(0, 0)) {
        let hanging = holdingCursor
        cursorPlay = nil; nextCursorPlay = clock + 3 + pick() * 3
        hangSwing = 0; swingRate = 0; shakeTimes = []
        guard hanging else { return }
        position.y -= hangDrop
        support = nil; cling = nil; fallFrom = nil; fallGrab = nil; fallTime = 0; leaping = false
        velocity = Point(max(-300, min(300, fling.x)), max(-200, min(300, fling.y)))
        change(.fall, .fall)
    }

    /// Look, go after it, rear up and swipe once it's in reach. A pointer high enough to dangle from gets
    /// grabbed with a little leap; a low one just gets batted. Returns true when it used this tick.
    mutating func tendCursorChase(_ cursor: Point?, on surface: Surface, surfaces: [Surface],
                                  windows: [DesktopWindow], screens: [Rect], dt: Double) -> Bool {
        guard let play = cursorPlay else { return false }
        guard let cursor, clock < play.until, let here = screen(of: position, in: screens), here.contains(cursor) else {
            endCursorPlay(missed: true); return false
        }
        let reach = reachPoint
        let toward: Double = cursor.x >= position.x ? 1 : -1
        let dx = abs(cursor.x - position.x), leapTop = reach.y + bodyHalfWidth * 1.5
        let inBand = cursor.y >= position.y - 4 && cursor.y <= leapTop
        switch play.phase {
        case .hang:
            return false
        case .notice(let until):
            direction = toward; change(.idle, .look)
            if clock >= until { cursorPlay?.phase = .stalk }
            return true
        case .swipe(let until):
            direction = toward; trickPose = .grab; change(.react, .play)
            guard clock >= until else { return true }
            if dx < bodyHalfWidth * 0.8 && inBand && hypot(cursorVelocity.x, cursorVelocity.y) < 900 {
                // Dangling would put it below the surface it stands on, so a low pointer only gets a bat.
                if cursor.y - hangDrop >= surface.y { grabCursor(cursor) }
                else { endCursorPlay(missed: true); change(.idle, .look) }
            } else { cursorPlay?.phase = .stalk }
            return true
        case .stalk:
            if dx < bodyHalfWidth * 0.6 && inBand {
                cursorPlay?.phase = .swipe(until: clock + 0.4)
                direction = toward; trickPose = .grab; change(.react, .play)
                return true
            }
            if !approach(cursor, on: surface, surfaces: surfaces, windows: windows, dt: dt, grab: true) {
                // As close as it can get but out of reach: stretch up for it (or peer down at it), briefly.
                direction = toward; running = false
                if cursor.y >= position.y { trickPose = .grab; change(.react, .play) } else { change(.idle, .sniff) }
                if let until = cursorPlay?.until, until > clock + 2 { cursorPlay?.until = clock + 2 }
            }
            return true
        }
    }

    /// One step toward `p` from the ledge underfoot: up the side of the window it's over, a leap to hang from that
    /// window's bottom edge, a leap at it, down off an end, up to a ledge beneath it, up the side of a window in
    /// the way, or a run along. Returns false when it can get no closer from here.
    mutating func approach(_ p: Point, on surface: Surface, surfaces: [Surface], windows: [DesktopWindow],
                           dt: Double, grab: Bool) -> Bool {
        let bw = bodyHalfWidth, rise = p.y - position.y, dx = p.x - position.x
        let over = Surfaces.frontmost(at: p, windows: windows)
        if clock >= nextChaseClimb {
            nextChaseClimb = clock + 0.5
            if let w = over, p.y < w.bounds.maxY - 2,
               p.y - w.bounds.minY <= bw * 2.5 || climbableEdge(of: w, from: surface, windows: windows, within: .infinity) == nil {
                // Its bottom edge is within a leap: jump up and hang from it (unless a side is the better way up).
                let x = min(max(position.x, w.bounds.minX + bw), w.bounds.maxX - bw)
                if abs(x - position.x) < bw * 0.4, w.bounds.minY > position.y + bw * 2, w.bounds.minY - position.y <= leapHeight,
                   clock >= nextLeap, canHang(under: w, surfaces: surfaces, windows: windows) {
                    leap(to: Point(position.x, w.bounds.minY - bw * 1.7), catching: w.id); return true
                }
            }
            // Above what it can reach standing on its hind legs: jump for it.
            if grab, abs(dx) < bw * 1.6, rise > bw * 3.2, rise <= leapHeight + bw, clock >= nextLeap {
                leap(to: p, catching: over?.id); return true
            }
            // A short way up: jump and pull itself onto the ledge. Higher, it climbs (below).
            if rise > bw * 1.6, let ledge = ledge(under: p, surfaces: surfaces), !agile || ledge.y - position.y <= bw * 4 {
                beginClimb(to: ledge); return true
            }
        }
        // The target on a window, or on top of it, out of reach: over to the window's nearer side and up its edge.
        if agile, rise > bw * 3, let w = over,
           let edge = climbableEdge(of: w, from: surface, windows: windows, within: .infinity, nearest: p.x) {
            if abs(edge.stand - position.x) < 4 {
                if grabSide(of: w, facing: edge.facing, toTop: p.y >= w.bounds.maxY - 2, surfaces: surfaces) { return true }
            } else {
                run(toward: edge.stand, on: surface, surfaces: surfaces, windows: windows, dt: dt); return true
            }
        }
        if rise < -bw && surface.kind.isLedge {
            // Below this ledge: hop off the end nearer the target, if nothing blocks it.
            let side: Double = abs(p.x - surface.left) < abs(p.x - surface.right) ? -1 : 1
            let edge = side > 0 ? surface.right : surface.left
            if Surfaces.wall(beyond: edge, facing: side, on: surface, windows: windows) == nil {
                if abs(edge - position.x) < 14 {
                    direction = side
                    // A long way down: back down the window's side rather than a leap.
                    if rise < -bw * 3, surface.kind == .window, let id = surface.windowID,
                       let w = windows.first(where: { $0.id == id }), abs(edge - (side > 0 ? w.bounds.maxX : w.bounds.minX)) < 1,
                       startEdgeDescent(from: w, toward: side, surfaces: surfaces, windows: windows) { return true }
                    hopOff(edge: edge)
                }
                else { run(toward: edge, on: surface, surfaces: surfaces, windows: windows, dt: dt) }
                return true
            }
        }
        // Along toward it, or to the part of the floor under the window it's on.
        var goal = p.x
        if let w = over, rise > bw { goal = min(max(p.x, w.bounds.minX + bw * 0.6), w.bounds.maxX - bw * 0.6) }
        guard abs(goal - position.x) >= 4 else { return false }
        let toward: Double = goal > position.x ? 1 : -1
        if run(toward: goal, on: surface, surfaces: surfaces, windows: windows, dt: dt) {
            let edge = toward > 0 ? surface.right : surface.left
            // A window standing in the way: up its side.
            if let wall = Surfaces.wall(beyond: edge, facing: toward, on: surface, windows: windows),
               grabSide(of: wall, facing: toward) { return true }
            // An open end with the target out beyond it: hop off that way.
            if surface.kind.isLedge, rise < bw * 2 { direction = toward; hopOff(edge: edge); return true }
            return false
        }
        return true
    }

    /// A jump at `target` (a point, or under a window's bottom edge), from a ledge or off a window side.
    mutating func leap(to target: Point, catching window: UInt32?) {
        let gravity = 1150.0
        let height = max(bodyHalfWidth * 0.8, min(leapHeight, target.y - position.y + bodyHalfWidth * 0.3))
        let vy = (2 * gravity * height).squareRoot(), time = vy / gravity
        let vx = max(-560, min(560, (target.x - position.x) / max(0.3, time)))
        cling = nil; lastClingOrigin = nil; climbTarget = nil; support = nil
        velocity = Point(vx, vy); leaping = true; leapCatch = window
        fallFrom = nil; fallGrab = nil; fallTime = 0; nextLeap = clock + 0.9
        if abs(vx) > 1 { direction = vx > 0 ? 1 : -1 }
        change(.fall, .fall); trickPose = .leap
    }

    /// While airborne: snatch the pointer it leapt at, hang from the bottom edge it leapt for, or, with sticky
    /// paws, catch the side of a window it's falling past. Returns true when it caught something.
    mutating func tendAirborne(cursor: Point?, surfaces: [Surface], windows: [DesktopWindow], dt: Double, sticky: Bool) -> Bool {
        guard agile else { return false }
        if leaping {
            trickPose = velocity.y > -120 ? .leap : nil
            if let cursor, let play = cursorPlay, play.chasing,
               hypot(cursor.x - reachPoint.x, cursor.y - reachPoint.y) < bodyHalfWidth * 0.9,
               hypot(cursorVelocity.x, cursorVelocity.y) < 900 {
                grabCursor(cursor); return true
            }
            if let id = leapCatch, let w = windows.first(where: { $0.id == id }) { return hang(under: w, windows: windows) }
            return false
        }
        guard sticky, cling == nil else { return false }
        fallTime += dt
        if fallGrab == nil { fallGrab = pick() < 0.6 }
        guard fallGrab == true, fallTime > 0.2, velocity.y < -60 else { return false }
        // Falling right past a window's side: claws out and grab the edge.
        for w in windows where w.id != fallFrom && w.bounds.height > bodyHalfWidth * 3 {
            for (x, facing) in [(w.bounds.minX, 1.0), (w.bounds.maxX, -1.0)]
            where abs(position.x - (x - facing * bodyHalfWidth * 0.4)) < bodyHalfWidth * 0.5 &&
                position.y + clingLift > w.bounds.minY + bodyHalfWidth && position.y + clingLift < w.bounds.maxY - bodyHalfWidth &&
                Surfaces.frontmost(at: Point(x + facing * 2, position.y + clingLift), windows: windows)?.id == w.id {
                position.x = x - facing * bodyHalfWidth * 0.4
                return grabSide(of: w, facing: facing, surfaces: surfaces)
            }
        }
        return false
    }

    /// Reaching up from a leap: forepaws hook the window's bottom edge and it hangs there.
    mutating func hang(under window: DesktopWindow, windows: [DesktopWindow]) -> Bool {
        let b = window.bounds, bw = bodyHalfWidth
        guard position.y + bw * 2 >= b.minY, position.y < b.minY, position.x > b.minX, position.x < b.maxX,
              Surfaces.frontmost(at: Point(position.x, b.minY + 2), windows: windows)?.id == window.id else { return false }
        let offset = Point(min(max(position.x - b.x, 0), b.width), 0)
        let heading = Point(velocity.x >= 0 ? 1 : -1, 0)
        var grip = Cling(window: window.id, offset: offset, side: .under, heading: heading, target: offset,
                         until: clock + 8 + pick() * 8)
        grip.target = Point(min(max(offset.x + heading.x * bw * 3, bw), max(bw, b.width - bw)), 0)
        turnFrom = (position, clock)
        cling = grip; lastClingOrigin = Point(b.x, b.y)
        velocity = Point(0, 0); fallGrab = nil; fallTime = 0; fallFrom = nil; leaping = false; leapCatch = nil
        climbHolding = false
        change(.climb, .climb); trickPose = Self.pose(for: grip)
        return true
    }

    /// Up the side of a window: belly to the edge, paws gripping it, body outside the window. With `toTop`, all
    /// the way to the top corner and over.
    mutating func grabSide(of wall: DesktopWindow, facing: Double, toTop: Bool = false, surfaces: [Surface] = []) -> Bool {
        let bw = bodyHalfWidth, h = wall.bounds.height
        guard agile, h > bw * 3 else { return false }
        let offset = Point(facing > 0 ? 0 : wall.bounds.width, min(max(position.y + clingLift - wall.bounds.y, bw * 0.6), h - bw))
        var grip = Cling(window: wall.id, offset: offset, side: facing > 0 ? .left : .right, heading: Point(0, 1),
                         target: Point(offset.x, min(h - bw, offset.y + bw * 3)), until: clock + 10 + pick() * 10)
        if toTop, let exit = exitPoint(on: wall, surfaces: surfaces, from: grip) {
            grip.target = exit.point; grip.exiting = true; grip.until = clock + h / 30 + 10
        }
        endTrick()
        position = Point(wall.bounds.x + offset.x, wall.bounds.y + offset.y)
        support = nil; velocity = Point(0, 0); climbTarget = nil
        cling = grip; climbHolding = false; turnFrom = nil
        lastClingOrigin = Point(wall.bounds.x, wall.bounds.y)
        direction = facing > 0 ? 1 : -1
        change(.climb, .climb); trickPose = Self.pose(for: grip)
        return true
    }

    /// A side of `w` it could climb from `surface`: reaching down to where it stands, clear of other windows, and
    /// with room beside it. Of those within `within` points of the pet, the one nearer it (or nearer `x`).
    func climbableEdge(of w: DesktopWindow, from surface: Surface, windows: [DesktopWindow], within: Double,
                       nearest x: Double? = nil) -> EdgeGrip? {
        let bw = bodyHalfWidth, b = w.bounds
        guard b.minY <= surface.y + clingLift, b.maxY > surface.y + bw * 4, b.height > bw * 4 else { return nil }
        let options: [EdgeGrip] = [(b.minX, 1.0), (b.maxX, -1.0)].compactMap { x, facing in
            let stand = x - facing * bw * 0.4
            guard surface.supports(stand, margin: bw * 0.5), abs(stand - position.x) <= within,
                  Surfaces.frontmost(at: Point(x + facing * 2, surface.y + clingLift + bw), windows: windows)?.id == w.id
            else { return nil }
            return EdgeGrip(window: w.id, facing: facing, stand: stand)
        }
        let goal = x ?? position.x
        return options.min { abs($0.stand - goal) < abs($1.stand - goal) }
    }

    /// The highest window top edge between the pet and the target, close enough to scramble up to.
    func ledge(under p: Point, surfaces: [Surface]) -> Surface? {
        surfaces.filter {
            $0.kind.isLedge && $0.supports(p.x) && $0.right - $0.left >= 60 &&
                $0.y > position.y + 24 && $0.y <= p.y + bodyHalfWidth && $0.y - position.y <= 420
        }.max { $0.y < $1.y }
    }

    /// Along the window's edges so its head (or, with `head` false, its paws) meets the target: up or down a side,
    /// hand over hand along the bottom, round a bottom corner. If the target is off the edges, to the nearest one
    /// and off it: over the top, a leap for it when it's within reach, or down and off.
    mutating func aimCling(at p: Point, windows: [DesktopWindow], surfaces: [Surface], pace: Double, head aimHead: Bool) {
        guard var grip = cling, let window = windows.first(where: { $0.id == grip.window }) else { return }
        let b = window.bounds, bw = bodyHalfWidth
        let head = aimHead ? Point(reachPoint.x - position.x, reachPoint.y - position.y) : Point(0, -bw * 0.9)
        let hang = canHang(under: window, surfaces: surfaces, windows: windows)
        // A leap carries it about six body-halves across, or two and a half up from hanging.
        let reachAcross = bw * 6, reachUp = bw * 2.5
        grip.then = nil; grip.exiting = false; grip.pace = pace
        /// The torso height on a side that puts its head level with `y`.
        func level(_ y: Double) -> Double { min(max(y - head.y - b.y, cornerHeight), max(cornerHeight, b.height - bw * 0.9)) }
        func overTheTop() -> Bool {
            guard let exit = exitPoint(on: window, surfaces: surfaces, from: grip) else { return false }
            grip.targetSide = exit.side; grip.target = exit.point; grip.exiting = true
            return true
        }
        /// Down and off: onto the ground beside this side, or along the bottom and drop, or just drop.
        func getDown(toward x: Double) {
            if grip.side != .under, let bottom = landingBottom(of: window, side: grip.side, surfaces: surfaces) {
                grip.targetSide = grip.side; grip.target = Point(grip.offset.x, bottom - b.y); grip.then = .dismount
            } else if hang, x > b.minX, x < b.maxX {
                grip.targetSide = .under; grip.target = Point(x - b.x, 0); grip.then = .drop
            } else {
                grip.then = .drop
            }
        }
        /// Out of reach: hold the nearest spot and give the chase up soon.
        func holdOn() {
            if let until = cursorPlay?.until, until > clock + 2 { cursorPlay?.until = clock + 2 }
        }
        let nearSide: ClingSide = grip.side == .under ? (p.x < b.midX ? .left : .right) : grip.side
        if p.y >= b.maxY - 1, p.x > b.minX - bw * 2, p.x < b.maxX + bw * 2 {
            // On or above the top: up to a corner and over; or with that corner covered, up this side and a leap
            // onto the top.
            if !overTheTop() {
                grip.targetSide = nearSide; grip.target = Point(nearSide == .left ? 0 : b.width, b.height - bw * 0.9)
                let edge = nearSide == .left ? b.minX : b.maxX
                if abs(p.x - edge) <= reachAcross { grip.then = .leap(p, head: aimHead) } else { getDown(toward: p.x) }
            }
        } else if p.y < b.minY - bw {
            // Below the window.
            getDown(toward: p.x)
        } else if p.x <= b.minX || p.x >= b.maxX {
            // Beside the window: level with it on that side (round the bottom if need be), then reach or leap.
            let side: ClingSide = p.x <= b.minX ? .left : .right
            if grip.side != side && grip.side != .under && !hang {
                if !overTheTop() { getDown(toward: p.x) }
            } else {
                grip.targetSide = side; grip.target = Point(side == .left ? 0 : b.width, level(p.y))
                let gap = abs(p.x - (side == .left ? b.minX : b.maxX))
                if gap > reachAcross { holdOn() } else if gap > bw * 1.2 { grip.then = .leap(p, head: aimHead) }
            }
        } else if grip.side == .under && p.y - b.minY <= reachUp {
            // Just above the bottom edge, hanging under it: along to below it, then a leap up for it.
            grip.targetSide = .under; grip.target = Point(p.x - b.x, 0); grip.then = .leap(p, head: aimHead)
        } else {
            // Over the window's face: level with it on the nearer side, then a leap across if it's in reach.
            grip.targetSide = nearSide
            grip.target = Point(nearSide == .left ? 0 : b.width, level(p.y))
            if abs(p.x - (nearSide == .left ? b.minX : b.maxX)) <= reachAcross { grip.then = .leap(p, head: aimHead) } else { holdOn() }
        }
        grip.until = max(grip.until, clock + 4)
        cling = grip
    }

    // MARK: Exploring

    /// Pick somewhere to go on its display: up a window's side edge, a window's top edge, its tree, or far across
    /// the floor. Returns false when there's nowhere new.
    mutating func startErrand(surfaces: [Surface], windows: [DesktopWindow], screens: [Rect], tree: TreeHome?) -> Bool {
        guard let here = screen(of: position, in: screens) else { return false }
        let roll = pick()
        var target: Point?
        let nearby = windows.filter { $0.bounds.width >= 120 && $0.bounds.height >= bodyHalfWidth * 4 && here.intersects($0.bounds) }
        if roll < 0.45, let floor = support, floor.kind == .floor {
            // Over to a window's side and up its edge, side on, to the top.
            let edges = nearby.compactMap { climbableEdge(of: $0, from: floor, windows: windows, within: here.width) }
                .sorted { abs($0.stand - position.x) < abs($1.stand - position.x) }.prefix(3)
            if let edge = edges.isEmpty ? nil : edges[min(edges.count - 1, Int(pick() * Double(edges.count)))] {
                errand = Errand(target: Point(edge.stand, floor.y), until: clock + 25, edge: edge)
                return true
            }
        } else if roll < 0.75 {
            let tops = surfaces.filter { $0.kind == .window && $0.right - $0.left >= 80 && here.contains(Point($0.left, $0.y)) }
            if !tops.isEmpty {
                let top = tops[min(tops.count - 1, Int(pick() * Double(tops.count)))]
                target = Point(top.left + 30 + pick() * max(0, top.right - top.left - 60), top.y)
            }
        } else if roll < 0.85, tree != nil {
            visitTree(for: 8 + pick() * 10); return true
        }
        if target == nil, let floor = surfaces.first(where: { $0.kind == .floor && here.contains(Point($0.left + 1, $0.y)) }) {
            let x = floor.left + 40 + pick() * max(0, floor.right - floor.left - 80)
            if abs(x - position.x) > 200 { target = Point(x, floor.y) }
        }
        guard let target, hypot(target.x - position.x, target.y - position.y) > bodyHalfWidth * 3 else { return false }
        errand = Errand(target: target, until: clock + 20)
        return true
    }

    /// Making its way to the errand's spot; a sniff and a look round when it gets there.
    mutating func tendErrand(on surface: Surface, surfaces: [Surface], windows: [DesktopWindow], dt: Double) -> Bool {
        guard let job = errand else { return false }
        guard clock < job.until else { errand = nil; return false }
        if var edge = job.edge, surface.kind == .floor {
            // The window may have moved or been covered on the way: keep to the side it has now, or give up.
            guard let w = windows.first(where: { $0.id == edge.window }),
                  let now = climbableEdge(of: w, from: surface, windows: windows, within: .infinity) else { errand = nil; return false }
            edge = now; errand?.edge = now; errand?.target.x = now.stand
            if abs(edge.stand - position.x) < 3 {
                errand = nil
                return grabSide(of: w, facing: edge.facing, toTop: true, surfaces: surfaces)
            }
            if run(toward: edge.stand, on: surface, surfaces: surfaces, windows: windows, dt: dt) { errand = nil; return false }
            return true
        }
        let arrived = abs(job.target.x - position.x) < bodyHalfWidth && abs(job.target.y - position.y) < 4
        if arrived || !approach(job.target, on: surface, surfaces: surfaces, windows: windows, dt: dt, grab: false) {
            errand = nil
            if arrived {
                // Somewhere new: a sniff round, and now and then a wash or a snack before moving on.
                let roll = pick()
                if roll < 0.2 { lounge = Lounge(pose: .groom, until: clock + 3 + pick() * 2) }
                else if roll < 0.35 { lounge = Lounge(pose: .nibble, until: clock + 3 + pick() * 3) }
                else { change(.idle, .sniff) }
                nextChoice = 0.8 + pick(); elapsed = 0
            }
            return arrived
        }
        return true
    }
}
