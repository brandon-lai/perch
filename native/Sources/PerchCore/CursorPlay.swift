import Foundation

/// Red panda cursor play: notice a lingering pointer, stalk it, rear up and swipe, then dangle from it chewing.
/// Only the pointer's current position and a smoothed velocity are used; nothing is recorded.
public struct CursorPlay: Equatable, Sendable {
    enum Phase: Equatable, Sendable { case notice(until: Double), stalk, swipe(until: Double), hang(until: Double) }
    var phase: Phase
    var until: Double
}

/// A held, research-based pose: washing its face, nibbling an apple, or rearing up with arms high.
struct Lounge: Equatable, Sendable {
    var pose: SpecialPose
    var until: Double
}

extension PetEngine {
    /// Dangling from the pointer. The app makes the pet click-through while this is true.
    public var holdingCursor: Bool { if case .hang = cursorPlay?.phase { return true }; return false }

    /// How far below the pointer the paw line sits while dangling, in points.
    var hangDrop: Double {
        bodyHalfWidth * 2 * (Double(PixelSprites.side - PixelSprites.hangGripRow) - 0.5) / Double(PixelSprites.side)
    }

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

    /// A pointer lingering nearby is irresistible; one whizzing right past makes it rear up.
    mutating func noticeCursor(_ cursor: Point?, dt: Double) -> Bool {
        guard agile, mischief.cursor, !gentle, cursorPlay == nil, let cursor, support != nil || cling != nil, trick == nil,
              climbTarget == nil, homeActivity == .exploring, state != .sleep, lounge?.pose != .grab else { return false }
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
        // Not when the pointer is resting on the pet itself: that's someone about to pet or pick it up.
        // With the bamboo pointer, not until there's a decent stalk to go after.
        guard clock >= nextCursorPlay, !bambooPointer || bamboo >= 0.6, distance > bodyHalfWidth * 0.9, distance < 320, speed < 800,
              pick() < dt * 0.6 else { return false }
        lounge = nil
        cursorPlay = CursorPlay(phase: .notice(until: clock + 0.5 + pick() * 0.5), until: clock + 10 + pick() * 8)
        direction = cursor.x >= position.x ? 1 : -1
        change(.idle, .look)
        return true
    }

    mutating func endCursorPlay() {
        if holdingCursor { dropFromCursor(); return }
        if cursorPlay != nil { nextCursorPlay = clock + 10 + pick() * 10 }
        cursorPlay = nil
    }

    mutating func grabCursor(_ cursor: Point) {
        // A bamboo stalk keeps it busy until it's eaten; a bare pointer only for a while.
        cursorPlay = CursorPlay(phase: .hang(until: clock + (bambooPointer ? 30 : 6 + pick() * 10)), until: clock + 40)
        support = nil; cling = nil; lastClingOrigin = nil; climbTarget = nil; lounge = nil; endTrick()
        // Leap from where its mouth is now; the hang pose is anchored at its teeth.
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
            dropFromCursor(fling: Point(cursorVelocity.x * 0.15, cursorVelocity.y * 0.15)); return
        }
        if bambooPointer {
            // About ten seconds of munching for a whole stalk; then down it hops, content.
            bamboo = max(0, bamboo - dt / 10)
            if bamboo == 0 { sated = true; dropFromCursor(); nextCursorPlay = clock + 25; return }
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
        cursorPlay = nil; nextCursorPlay = clock + 20 + pick() * 20
        hangSwing = 0; swingRate = 0; shakeTimes = []
        guard hanging else { return }
        position.y -= hangDrop
        support = nil; cling = nil; fallFrom = nil; fallGrab = nil; fallTime = 0
        velocity = Point(max(-300, min(300, fling.x)), max(-200, min(300, fling.y)))
        change(.fall, .fall)
    }

    /// Look, stalk along the surface underfoot (or climb toward it), rear up and swipe once it's in reach.
    /// A pointer high enough to dangle from gets grabbed with a little leap; a low one just gets batted.
    /// Returns true when it used this tick.
    mutating func tendCursorChase(_ cursor: Point?, on surface: Surface, surfaces: [Surface],
                                  windows: [DesktopWindow], dt: Double) -> Bool {
        guard let play = cursorPlay else { return false }
        guard let cursor, clock < play.until else { endCursorPlay(); return false }
        let reach = reachPoint
        guard hypot(cursor.x - reach.x, cursor.y - reach.y) < 600 else { endCursorPlay(); return false }
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
                else { endCursorPlay(); change(.idle, .look) }
            } else { cursorPlay?.phase = .stalk }
            return true
        case .stalk:
            if dx < bodyHalfWidth * 0.6 && inBand {
                cursorPlay?.phase = .swipe(until: clock + 0.45)
                direction = toward; trickPose = .grab; change(.react, .play)
                return true
            }
            if cursor.y > leapTop, clock >= nextChaseClimb {
                nextChaseClimb = clock + 0.8
                // Up (or over the top and down) the window face toward it, or onto a ledge beneath it.
                if startScramble(windows: windows, toward: cursor) { return true }
                if let ledge = ledge(under: cursor, surfaces: surfaces) { beginClimb(to: ledge); return true }
            }
            if cursor.y < position.y - bodyHalfWidth && surface.kind == .window {
                if clock >= nextChaseClimb {
                    nextChaseClimb = clock + 0.8
                    if startScramble(windows: windows, toward: cursor) { return true }
                }
                // Below this ledge: hop off the end nearer the pointer, if nothing blocks it.
                let side: Double = abs(cursor.x - surface.left) < abs(cursor.x - surface.right) ? -1 : 1
                let edge = side > 0 ? surface.right : surface.left
                if Surfaces.wall(beyond: edge, facing: side, on: surface, windows: windows) == nil {
                    if abs(edge - position.x) < 14 { direction = side; hopOff(edge: edge) }
                    else { run(toward: edge, on: surface, surfaces: surfaces, windows: windows, dt: dt) }
                    return true
                }
            }
            let blocked = dx < 6 || run(toward: cursor.x, on: surface, surfaces: surfaces, windows: windows, dt: dt)
            if blocked {
                // As close as it can get but out of reach: stretch up for it (or peer down at it), briefly.
                direction = toward; running = false
                if cursor.y >= position.y { trickPose = .grab; change(.react, .play) } else { change(.idle, .sniff) }
                if let until = cursorPlay?.until, until > clock + 2.5 { cursorPlay?.until = clock + 2.5 }
            }
            return true
        }
    }

    /// The highest window top edge between the pet and the pointer, close enough to scramble up to.
    func ledge(under cursor: Point, surfaces: [Surface]) -> Surface? {
        surfaces.filter {
            $0.kind == .window && $0.supports(cursor.x) && $0.right - $0.left >= 60 &&
                $0.y > position.y + 24 && $0.y <= cursor.y && $0.y - position.y <= 420
        }.max { $0.y < $1.y }
    }

    /// On a window face, crawl so its head meets the pointer rather than wandering to a random spot.
    mutating func aimCling(at cursor: Point, windows: [DesktopWindow]) {
        guard var grip = cling, let window = windows.first(where: { $0.id == grip.window }) else { return }
        let head = Point(reachPoint.x - position.x, reachPoint.y - position.y)
        grip.target = Point(min(max(cursor.x - head.x - window.bounds.x, 0), window.bounds.width),
                            min(max(cursor.y - head.y - window.bounds.y, 0), window.bounds.height))
        grip.exiting = false
        grip.until = max(grip.until, clock + 4)
        cling = grip
    }

    /// Sticky paws: falling past a window face, it sometimes catches hold and climbs on from there.
    mutating func catchWindowWhileFalling(windows: [DesktopWindow], dt: Double, allowed: Bool) -> Bool {
        guard agile, cling == nil, allowed else { return false }
        fallTime += dt
        if fallGrab == nil { fallGrab = pick() < 0.6 }
        guard fallGrab == true, fallTime > 0.2, velocity.y < -60,
              let window = Surfaces.frontmost(at: Point(position.x, position.y + bodyHalfWidth), windows: windows),
              window.id != fallFrom, window.bounds.width >= 80, window.bounds.height >= bodyHalfWidth * 3 else { return false }
        let offset = Point(min(max(position.x - window.bounds.x, 20), window.bounds.width - 20),
                           min(max(position.y - window.bounds.y, 0), window.bounds.height - bodyHalfWidth * 2))
        var grip = Cling(window: window.id, offset: offset, side: .front, heading: Point(0, -1),
                         target: offset, until: clock + 8 + pick() * 12)
        grip.target = faceTarget(on: window, windows: windows) ?? offset
        grip.heading = Self.heading(from: grip.offset, to: grip.target) ?? grip.heading
        cling = grip; lastClingOrigin = Point(window.bounds.x, window.bounds.y)
        position = Point(window.bounds.x + offset.x, window.bounds.y + offset.y)
        velocity = Point(0, 0); fallGrab = nil; fallTime = 0; fallFrom = nil
        change(.climb, .climb); trickPose = grip.heading.y < -0.3 ? .descend : .crawl
        return true
    }
}
