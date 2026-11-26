import Foundation

/// Red panda cursor play: notice the pointer anywhere on its display, go after it (along ledges, up window faces,
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

/// Somewhere it has decided to explore: a spot on a window face, a window's top edge, or across the floor.
struct Errand: Equatable, Sendable {
    var target: Point
    var until: Double
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

    /// Where its forepaws reach when it rears up, or where its head is while it climbs a window face.
    var reachPoint: Point {
        if let grip = cling, grip.side == .front, grip.heading.y < -0.3 { return Point(position.x, position.y + bodyHalfWidth * 0.35) }
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

    /// One step toward `p` from the ledge underfoot: onto the window face it's on, a leap up to it, down off an
    /// end, up to a ledge beneath it, up the side of a window in the way, or a run along. Returns false when it
    /// can get no closer from here.
    mutating func approach(_ p: Point, on surface: Surface, surfaces: [Surface], windows: [DesktopWindow],
                           dt: Double, grab: Bool) -> Bool {
        let bw = bodyHalfWidth, rise = p.y - position.y, dx = p.x - position.x
        let over = Surfaces.frontmost(at: p, windows: windows)
        if clock >= nextChaseClimb {
            nextChaseClimb = clock + 0.5
            if let w = over {
                // Over the top edge underfoot and down, or onto the window right behind it.
                if startScramble(windows: windows, toward: p) { return true }
                // Its bottom edge is within a leap: jump up and grab on.
                let x = min(max(position.x, w.bounds.minX + bw * 0.6), w.bounds.maxX - bw * 0.6)
                if abs(x - position.x) < bw * 0.4, w.bounds.minY > position.y, w.bounds.minY - position.y <= leapHeight,
                   clock >= nextLeap {
                    leap(to: Point(position.x, w.bounds.minY + bw), catching: w.id); return true
                }
            }
            // Above what it can reach standing on its hind legs: jump for it.
            if grab, abs(dx) < bw * 1.6, rise > bw * 3.2, rise <= leapHeight + bw, clock >= nextLeap {
                leap(to: p, catching: over?.id); return true
            }
            if rise > bw * 1.6, let ledge = ledge(under: p, surfaces: surfaces) { beginClimb(to: ledge); return true }
        }
        if rise < -bw && surface.kind.isLedge {
            // Below this ledge: hop off the end nearer the target, if nothing blocks it.
            let side: Double = abs(p.x - surface.left) < abs(p.x - surface.right) ? -1 : 1
            let edge = side > 0 ? surface.right : surface.left
            if Surfaces.wall(beyond: edge, facing: side, on: surface, windows: windows) == nil {
                if abs(edge - position.x) < 14 { direction = side; hopOff(edge: edge) }
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

    /// A jump at `target` (a point or a window's face), from a ledge or off a window side.
    mutating func leap(to target: Point, catching window: UInt32?) {
        let gravity = 1150.0
        let height = max(bodyHalfWidth * 0.8, min(leapHeight, target.y - position.y + bodyHalfWidth * 0.3))
        let vy = (2 * gravity * height).squareRoot(), time = vy / gravity
        let vx = max(-420, min(420, (target.x - position.x) / max(0.3, time)))
        cling = nil; lastClingOrigin = nil; climbTarget = nil; support = nil
        velocity = Point(vx, vy); leaping = true; leapCatch = window
        fallFrom = nil; fallGrab = nil; fallTime = 0; nextLeap = clock + 0.9
        if abs(vx) > 1 { direction = vx > 0 ? 1 : -1 }
        change(.fall, .fall); trickPose = .leap
    }

    /// While airborne: snatch the pointer it leapt at, grab the window face it aimed for, or, with sticky paws,
    /// catch hold of a window it's falling past. Returns true when it caught something.
    mutating func tendAirborne(cursor: Point?, windows: [DesktopWindow], dt: Double, sticky: Bool) -> Bool {
        guard agile else { return false }
        if leaping {
            trickPose = velocity.y > -120 ? .leap : nil
            if let cursor, let play = cursorPlay, play.chasing,
               hypot(cursor.x - reachPoint.x, cursor.y - reachPoint.y) < bodyHalfWidth * 0.9,
               hypot(cursorVelocity.x, cursorVelocity.y) < 900 {
                grabCursor(cursor); return true
            }
            if let id = leapCatch, let w = Surfaces.frontmost(at: Point(position.x, position.y + bodyHalfWidth), windows: windows),
               w.id == id {
                return cling(to: w, windows: windows)
            }
            return false
        }
        guard sticky, cling == nil else { return false }
        fallTime += dt
        if fallGrab == nil { fallGrab = pick() < 0.6 }
        guard fallGrab == true, fallTime > 0.2, velocity.y < -60,
              let window = Surfaces.frontmost(at: Point(position.x, position.y + bodyHalfWidth), windows: windows),
              window.id != fallFrom else { return false }
        return cling(to: window, windows: windows)
    }

    /// Take hold of a window's face where the pet is.
    mutating func cling(to window: DesktopWindow, windows: [DesktopWindow]) -> Bool {
        guard window.bounds.width >= 80, window.bounds.height >= bodyHalfWidth * 3 else { return false }
        let offset = Point(min(max(position.x - window.bounds.x, 20), window.bounds.width - 20),
                           min(max(position.y - window.bounds.y, 0), window.bounds.height - bodyHalfWidth * 2))
        var grip = Cling(window: window.id, offset: offset, side: .front, heading: Point(0, 1),
                         target: offset, until: clock + 6 + pick() * 6)
        grip.target = faceTarget(on: window, windows: windows) ?? offset
        grip.heading = Self.heading(from: grip.offset, to: grip.target) ?? grip.heading
        cling = grip; lastClingOrigin = Point(window.bounds.x, window.bounds.y)
        position = Point(window.bounds.x + offset.x, window.bounds.y + offset.y)
        velocity = Point(0, 0); fallGrab = nil; fallTime = 0; fallFrom = nil; leaping = false; leapCatch = nil
        change(.climb, .climb); trickPose = grip.heading.y < -0.3 ? .descend : .crawl
        return true
    }

    /// Up the side of a window standing in its way: paws on the edge, body outside it.
    mutating func grabSide(of wall: DesktopWindow, facing: Double) -> Bool {
        guard agile, wall.bounds.height > bodyHalfWidth * 3 else { return false }
        let offset = Point(facing > 0 ? 0 : wall.bounds.width, min(max(position.y - wall.bounds.y, 0), wall.bounds.height))
        let target = Point(offset.x, min(wall.bounds.height - bodyHalfWidth, offset.y + bodyHalfWidth * 3))
        endTrick()
        support = nil; velocity = Point(0, 0); climbTarget = nil
        cling = Cling(window: wall.id, offset: offset, side: facing > 0 ? .left : .right, heading: Point(0, 1),
                      target: target, until: clock + 10 + pick() * 10)
        lastClingOrigin = Point(wall.bounds.x, wall.bounds.y)
        change(.climb, .climb); trickPose = .scale
        return true
    }

    /// The highest window top edge between the pet and the target, close enough to scramble up to.
    func ledge(under p: Point, surfaces: [Surface]) -> Surface? {
        surfaces.filter {
            $0.kind.isLedge && $0.supports(p.x) && $0.right - $0.left >= 60 &&
                $0.y > position.y + 24 && $0.y <= p.y + bodyHalfWidth && $0.y - position.y <= 420
        }.max { $0.y < $1.y }
    }

    /// On a window face, crawl so its head meets the target. If the target is off this window, head for the
    /// edge nearest it: over the top, to a side and leap, or down to the bottom and drop.
    mutating func aimCling(at p: Point, windows: [DesktopWindow], surfaces: [Surface], pace: Double) {
        guard var grip = cling, let window = windows.first(where: { $0.id == grip.window }) else { return }
        let b = window.bounds
        let head = Point(reachPoint.x - position.x, reachPoint.y - position.y)
        grip.then = nil; grip.exiting = false; grip.pace = pace
        if p.y >= b.maxY - 1, p.x > b.minX, p.x < b.maxX,
           let exit = exitPoint(on: window, surfaces: surfaces, from: Point(p.x - b.x, b.height)) {
            // On or above the top edge: over the top to get there.
            grip.target = exit; grip.exiting = true
        } else if Surfaces.frontmost(at: p, windows: windows)?.id == window.id {
            grip.target = Point(min(max(p.x - head.x - b.x, 0), b.width), min(max(p.y - head.y - b.y, 0), b.height))
        } else if p.x <= b.minX || p.x >= b.maxX {
            grip.target = Point(p.x <= b.minX ? 0 : b.width,
                                min(max(p.y - b.y, bodyHalfWidth), max(bodyHalfWidth, b.height - bodyHalfWidth)))
            grip.then = .leap(p)
        } else {
            grip.target = Point(min(max(p.x - b.x, 20), b.width - 20), 0); grip.then = .drop
        }
        grip.until = max(grip.until, clock + 4)
        cling = grip
    }

    // MARK: Exploring

    /// Pick somewhere to go on its display: a spot on a window face, a window's top edge, its tree, or far across
    /// the floor. Returns false when there's nowhere new.
    mutating func startErrand(surfaces: [Surface], windows: [DesktopWindow], screens: [Rect], tree: TreeHome?) -> Bool {
        guard let here = screen(of: position, in: screens) else { return false }
        let roll = pick()
        var target: Point?
        let faces = windows.filter { $0.bounds.width >= 120 && $0.bounds.height >= bodyHalfWidth * 4 && here.intersects($0.bounds) }
        if roll < 0.45, !faces.isEmpty {
            let w = faces[min(faces.count - 1, Int(pick() * Double(faces.count)))]
            target = faceTarget(on: w, windows: windows).map { Point(w.bounds.x + $0.x, w.bounds.y + $0.y) }
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
