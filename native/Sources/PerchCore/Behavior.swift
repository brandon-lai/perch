import Foundation

public enum PetState: String, CaseIterable, Sendable { case idle, react, sit, sleep, held, fall, ride, walk, climb }
public struct Rhythm: Sendable {
    public var hour: Int
    public var idleSeconds: Double
    public var calm: Bool
    public var quietStart: Int
    public var quietEnd: Int
    public var quietEnabled: Bool
    public init(hour: Int = 12, idleSeconds: Double = 0, calm: Bool = false,
                quietStart: Int = 22, quietEnd: Int = 7, quietEnabled: Bool = true) {
        self.hour = hour; self.idleSeconds = idleSeconds; self.calm = calm
        self.quietStart = quietStart; self.quietEnd = quietEnd; self.quietEnabled = quietEnabled
    }
    public var quiet: Bool {
        guard quietEnabled else { return false }
        if quietStart == quietEnd { return true }
        return quietStart < quietEnd ? hour >= quietStart && hour < quietEnd : hour >= quietStart || hour < quietEnd
    }
}
public struct PetEngine: Sendable {
    public private(set) var state: PetState = .fall
    public private(set) var action: Action = .fall
    public var position: Point
    public internal(set) var velocity = Point(0, 0)
    public internal(set) var support: Surface?
    public internal(set) var direction: Double = 1
    public internal(set) var bed = false
    var elapsed: Double = 0
    var nextChoice: Double = 4
    private var random: UInt64 = 0x5045524348
    var overrideUntil = 0.0
    var clock = 0.0
    var actionRemaining = 0.0
    var climbTarget: Surface?
    private var climbFrom = Point(0, 0)
    private var nextTug = 45.0
    private var homeTime = 0.0
    public internal(set) var homeActivity: HomeActivity = .exploring
    public var care = PetCare()
    /// How far below a ledge the pet's paw line sits while it hangs on with its front paws.
    public var hangDepth = 24.0
    /// Which mischief the app currently allows. Everything is off until the app opts in.
    public var mischief = Mischief()
    /// Half the sprite's width and its nose's reach from the paw anchor, in points.
    public var bodyHalfWidth = 48.0
    public var muzzleReach = 42.0
    public internal(set) var ball: Ball?
    public internal(set) var trickPose: SpecialPose?
    public internal(set) var running = false
    var trick: Trick?
    /// Red pandas: climb window faces and sides as well as top edges.
    public var agile = false
    public internal(set) var cling: Cling?
    var lastClingOrigin: Point?
    var nextScramble = 6.0
    /// Calm pets still wander, just slower, with longer pauses and no mischief.
    var gentle = false
    var events: [PetEvent] = []
    var nextChew = 20.0, nextPlay = 30.0, nextPush = 0.0, ballExpiry = 0.0, ballDeadline = 0.0
    /// The pointer's position last tick and its smoothed velocity. Nothing older is kept.
    var lastCursor: Point?
    var cursorVelocity = Point(0, 0)
    public internal(set) var cursorPlay: CursorPlay?
    /// How far the pet swings from the pointer while dangling from it, in radians (counterclockwise).
    public internal(set) var hangSwing = 0.0
    var swingRate = 0.0, shakeSign = 0.0, shakeTimes: [Double] = []
    var nextCursorPlay = 3.0, nextStartle = 0.0, nextChaseClimb = 0.0, leapUntil = 0.0
    var lounge: Lounge?
    /// The pointer carries a bamboo stalk: the panda plays with its bottom end and eats it while it hangs on.
    public var bambooPointer = false
    /// How much of the stalk is left (1 is whole). It grows back while the panda isn't eating it.
    public internal(set) var bamboo = 1.0
    /// Finished a whole stalk: lands happy.
    var sated = false
    var zoomUntil = 0.0
    /// While falling: the window it just left, whether it will try to grab a window face, and for how long it has fallen.
    var fallFrom: UInt32?
    var fallGrab: Bool?
    var fallTime = 0.0
    public init(position: Point) { self.position = position }
    public mutating func setBed(_ value: Bool) {
        homeActivity = .exploring; climbTarget = nil; endTrick(); cling = nil; lastClingOrigin = nil
        if holdingCursor { dropFromCursor() }
        cursorPlay = nil; lounge = nil
        bed = value
        if value { change(.sleep, .sleep) } else { overrideUntil = clock + 300; change(support == nil ? .fall : .idle, support == nil ? .fall : .idle) }
    }
    public mutating func hold(at point: Point) {
        endTrick(); cling = nil; lastClingOrigin = nil; homeActivity = .exploring; climbTarget = nil
        if cursorPlay != nil { endCursorPlay(); cursorPlay = nil }
        lounge = nil; hangSwing = 0
        position = point; support = nil; velocity = Point(0, 0); change(.held, .held)
    }
    public mutating func drag(to point: Point) { if state == .held { position = point } }
    public mutating func release() {
        if holdingCursor { cursorPlay = nil; hangSwing = 0 }
        fallFrom = nil; fallGrab = nil; fallTime = 0
        cling = nil; lastClingOrigin = nil; homeActivity = .exploring; climbTarget = nil; support = nil; velocity = Point(0, 0); change(.fall, .fall)
    }
    public mutating func react(_ selected: Action = .pet) {
        // Holding on to a window face: enjoy the attention without letting go.
        guard state != .held, cling == nil, !holdingCursor else { overrideUntil = clock + 300; return }
        homeActivity = .exploring; endTrick(); lounge = nil
        if cursorPlay != nil { endCursorPlay() }
        bed = false; overrideUntil = clock + 300
        change(.react, selected); actionRemaining = 2
    }
    public mutating func relocate(_ point: Point) { position = point; release(); bed = false }
    public mutating func perch(on surface: Surface, x: Double) {
        climbTarget = nil
        support = surface; position = Point(x, surface.y); velocity = Point(0, 0); change(.sit, .sit)
    }
    public mutating func climb(to surface: Surface) {
        endTrick(); cling = nil; lastClingOrigin = nil; homeActivity = .exploring; bed = false; overrideUntil = clock + 300
        if holdingCursor { dropFromCursor() }
        cursorPlay = nil; lounge = nil
        beginClimb(to: surface)
    }
    public func windowToClimb(surfaces: [Surface], screens: [Rect], nearbyOnly: Bool) -> Surface? {
        guard let screen = screens.first(where: { $0.contains(position) }) else { return nil }
        func distance(_ ledge: Surface) -> Double {
            hypot(max(0, max(ledge.left - position.x, position.x - ledge.right)), ledge.y - position.y)
        }
        let candidates = surfaces.filter { ledge in
            let x = max(ledge.left + 20, min(position.x, ledge.right - 20))
            return ledge.kind == .window && ledge.windowID != support?.windowID &&
                ledge.right - ledge.left >= 80 && ledge.y + 100 <= screen.maxY &&
                screen.contains(Point(x, ledge.y)) && (!nearbyOnly ||
                    (ledge.y > position.y + 24 && position.x >= ledge.left - 80 && position.x <= ledge.right + 80))
        }
        let above = candidates.filter { $0.y > position.y + 24 }
        return (above.isEmpty ? candidates : above).min { distance($0) < distance($1) }
    }
    mutating func beginClimb(to surface: Surface) {
        climbFrom = position; climbTarget = surface
        nextTug = 45
        support = nil; change(.climb, .climb); elapsed = 0
    }
    public mutating func fillBowl() {
        guard homeActivity != .eating else { return }
        care.fill()
        if bed { setBed(false) }
        overrideUntil = clock + 300
        if state != .held { climbTarget = nil; homeActivity = .goingToBowl }
    }
    mutating func change(_ newState: PetState, _ newAction: Action) {
        if state != newState || action != newAction { elapsed = 0 }
        state = newState; action = newAction
    }
    mutating func pick() -> Double {
        random = random &* 6364136223846793005 &+ 1
        return Double(random >> 32) / Double(UInt32.max)
    }
    public mutating func tick(dt rawDT: Double, surfaces: [Surface], screens: [Rect], rhythm: Rhythm,
                              surfaceDT: Double? = nil, home: DesktopHome? = nil, reduceMotion: Bool = false,
                              windows: [DesktopWindow] = [], cursor: Point? = nil) {
        let dt = max(0, min(rawDT.isFinite ? rawDT : 0, 0.1))
        let wallDT = max(0, min(rawDT.isFinite ? rawDT : 0, 1))
        clock += wallDT; elapsed += wallDT; actionRemaining -= wallDT
        running = false; trickPose = nil; gentle = rhythm.calm
        tickBall(dt: dt, surfaces: surfaces, screens: screens, windows: windows)
        trackCursor(cursor, dt: wallDT)
        if !holdingCursor { bamboo = min(1, bamboo + wallDT / 40) }
        guard state != .held else { return }
        let resting = rhythm.quiet || rhythm.idleSeconds >= 300
        let unplayful = bed || reduceMotion || !agile || !mischief.cursor || gentle ||
            (resting && clock >= overrideUntil) || homeActivity != .exploring
        if holdingCursor {
            tendHang(cursor, dt: dt, restless: unplayful)
            if holdingCursor { return }
        } else if cursorPlay != nil && unplayful { endCursorPlay() }
        if bed { endTrick(); change(.sleep, .sleep); if agile && support?.kind == .window { trickPose = .drape }; return }
        if home != nil {
            if !resting && homeActivity != .napping && homeActivity != .eating { care.advance(wallDT) }
        } else { homeActivity = .exploring }
        if cling != nil {
            let restless = (resting && clock >= overrideUntil) || reduceMotion || !agile ||
                (home != nil && (care.isHungry || care.foodInBowl))
            if cursorPlay == nil && !restless { _ = noticeCursor(cursor, dt: dt) }
            if let play = cursorPlay {
                if restless || clock > play.until { endCursorPlay() }
                else if let cursor {
                    let head = reachPoint
                    if hypot(cursor.x - head.x, cursor.y - head.y) < bodyHalfWidth * 0.9 { grabCursor(cursor); return }
                    aimCling(at: cursor, windows: windows)
                } else { endCursorPlay() }
            }
            tendCling(dt: dt, surfaceDT: surfaceDT, surfaces: surfaces, windows: windows, restless: restless)
            return
        }
        if state == .climb, let target = climbTarget {
            guard let current = surfaces.first(where: {
                target.windowID != nil ? $0.windowID == target.windowID && $0.supports((target.left + target.right) / 2) : $0.id == target.id
            }) else { release(); return }
            let x = min(max(climbFrom.x, current.left + 20), current.right - 20)
            let tug = target.kind == .window && climbFrom.y < current.y - hangDepth
            let approach = max(0.56, hypot(current.y - climbFrom.y, x - climbFrom.x) / 500)
            let duration = tug ? approach + 1.04 : 0.7
            let time = reduceMotion ? duration : min(duration, elapsed)
            if tug {
                // Approach the lip, hang for two little pulls, then bring the back paws up.
                let reach = min(1, time / approach), haul = max(0, (time - approach - 0.69) / 0.35)
                let pulls = sin(.pi * 2 * max(0, min(1, (time - approach) / 0.69)))
                position = Point(climbFrom.x + (x - climbFrom.x) * reach,
                    climbFrom.y + (current.y - hangDepth - climbFrom.y) * reach + 6 * pulls * pulls + hangDepth * haul)
            } else {
                let t = time / duration
                let eased = 1 - pow(1 - t, 2)
                position = Point(climbFrom.x + (x - climbFrom.x) * eased,
                    climbFrom.y + (current.y - climbFrom.y) * eased + sin(t * .pi) * 32)
            }
            if time >= duration {
                climbTarget = nil; support = current; position = Point(x, current.y)
                change(.sit, current.kind == .menu ? .peek : .sit)
                nextChoice = current.kind == .menu ? 6 + pick() * 4 : 1.5 + pick() * 2
            }
            return
        }
        var riding = false
        var detachedWindow: UInt32?
        if let previous = support {
            let current = surfaces.first {
                if let id = previous.windowID { return $0.windowID == id && $0.supports(position.x + $0.origin.x - previous.origin.x) }
                return $0.id == previous.id
            }
            if let current {
                let dx = current.origin.x - previous.origin.x, dy = current.origin.y - previous.origin.y
                let movementDT = max(surfaceDT ?? dt, 0.001)
                let speed = hypot(dx, dy) / movementDT
                // Red pandas hold on through a brisk drag; everyone else slides off a fast-moving window.
                if speed > (agile ? 1300 : 650) {
                    detachedWindow = previous.windowID; fallFrom = previous.windowID
                    velocity = Point(max(-220, min(220, dx / movementDT)), 20)
                    support = nil; change(.fall, .fall)
                } else {
                    position.x += dx; position.y = current.y; support = current
                    riding = hypot(dx, dy) > 0.05
                }
            } else { support = nil; change(.fall, .fall) }
        }
        if support == nil {
            if case .chase = trick {} else { endTrick() }
            lounge = nil
            change(.fall, .fall)
            if catchWindowWhileFalling(windows: windows, dt: dt,
                                       allowed: trick == nil && homeActivity == .exploring && !resting && !reduceMotion) { return }
            let oldY = position.y
            velocity.y = max(-1000, velocity.y - 1150 * dt)
            position.x += velocity.x * dt; position.y += velocity.y * dt
            let landing = surfaces.filter {
                $0.kind != .menu && (detachedWindow == nil || $0.windowID != detachedWindow) &&
                $0.supports(position.x) && $0.y <= oldY + 0.5 && $0.y >= position.y
            }.max { $0.y < $1.y } ?? floorBelow(surfaces: surfaces, screens: screens)
            if let landing {
                support = landing; position.y = landing.y; velocity = Point(0, 0)
                fallFrom = nil; fallGrab = nil; fallTime = 0
                if sated { sated = false; change(.react, .pet); actionRemaining = 1.8 }
                else { change(.react, .shake); actionRemaining = 1 }
            }
        } else if riding {
            change(.ride, .ride); elapsed = 0
        } else if state == .ride && elapsed > 0.18 { change(.idle, .idle) }
        if support != nil && !riding {
            if let home, !resting || clock < overrideUntil {
                if tendHome(home, dt: dt, wallDT: wallDT, still: reduceMotion) { endTrick(); lounge = nil; return }
            }
            if cursorPlay != nil, let surface = support, !(state == .react && action == .shake && actionRemaining > 0),
               tendCursorChase(cursor, on: surface, surfaces: surfaces, windows: windows, dt: dt) { return }
            if trick != nil {
                if resting && clock >= overrideUntil { endTrick() }
                else if !(state == .react && action == .shake && actionRemaining > 0),
                        tendTrick(dt: dt, surfaces: surfaces, windows: windows) { return }
            }
            if let pose = lounge {
                if clock < pose.until && !(resting && clock >= overrideUntil) && !reduceMotion {
                    // Even mid-wash, a pointer can steal its attention.
                    if pose.pose != .grab && noticeCursor(cursor, dt: dt) { return }
                    trickPose = lounge?.pose ?? pose.pose; change(.idle, pose.pose == .grab ? .look : .sit)
                    return
                }
                lounge = nil; nextChoice = 0; elapsed = 0
            }
            if resting && clock >= overrideUntil {
                change(.sleep, .sleep)
            } else if state == .sleep { change(.idle, .stretch); actionRemaining = 2 }
            // Warm and up high: sprawled over the edge with its legs dangling, as red pandas sleep on branches.
            if state == .sleep && agile && support?.kind == .window { trickPose = .drape }
            if state == .react || state == .climb {
                // A brief beat after a reaction, then back to exploring rather than idling out a stale timer.
                if actionRemaining <= 0 { change(.idle, .idle); nextChoice = 0.5 + pick() }
            } else if support?.kind == .menu {
                if elapsed >= nextChoice { support = nil; velocity = Point(0, 0); change(.fall, .fall) }
            } else if state != .sleep {
                if !rhythm.calm && !reduceMotion && !resting {
                    nextTug -= wallDT
                    if nextTug <= 0 {
                        nextTug = 12
                        if let target = windowToClimb(surfaces: surfaces, screens: screens, nearbyOnly: true) {
                            beginClimb(to: target); return
                        }
                    }
                }
                // Reduce Motion keeps the pet still; everything else wanders.
                if reduceMotion { change(.sit, .sit) }
                else if noticeCursor(cursor, dt: dt) { return }
                else if elapsed >= nextChoice {
                    let value = pick()
                    if !gentle && mischief.play && clock >= nextPlay && value < 0.14 { startPlay(); return }
                    if !gentle && mischief.chew && clock >= nextChew && value < 0.32 && startChew() { return }
                    // Red pandas are forever climbing something.
                    if agile && !gentle && clock >= nextScramble && value >= 0.32 && value < 0.72 && startScramble(windows: windows) { return }
                    // Mostly on the move; short pauses keep it from looking mechanical. Calm pets pause more.
                    let pause = pick(), walk = gentle ? 0.5 : agile ? 0.62 : 0.70
                    if pause < walk { change(.walk, .walk); if pick() < 0.3 { direction *= -1 } }
                    else if agile && !gentle {
                        // Red panda pauses from zoo time budgets: sniffing, face-washing, a snack held in the
                        // forepaws, and the occasional sudden bound.
                        if pause < 0.70 { change(.idle, .sniff) }
                        else if pause < 0.78 { lounge = Lounge(pose: .groom, until: clock + 5 + pick() * 5); return }
                        else if pause < 0.85 { lounge = Lounge(pose: .nibble, until: clock + 7 + pick() * 7); return }
                        else if pause < 0.91 {
                            zoomUntil = clock + 2 + pick() * 3; change(.walk, .walk)
                            if pick() < 0.5 { direction *= -1 }
                        } else { change(.sit, .sit) }
                    }
                    else if pause < walk + 0.10 { change(.idle, .sniff) }
                    else if pause < walk + (gentle ? 0.40 : 0.19) { change(.sit, .sit) }
                    else if pause < walk + (gentle ? 0.46 : 0.25) { change(.idle, .stretch) }
                    else { change(.idle, .yawn) }
                    elapsed = 0
                    nextChoice = state == .walk ? (gentle ? 4 + pick() * 5 : 5 + pick() * 7)
                                                : (gentle ? 4 + pick() * 5 : 2 + pick() * 2.5)
                }
                if state == .walk, let surface = support {
                    let bounding = clock < zoomUntil
                    wander(on: surface, surfaces: surfaces, windows: windows, dt: dt, pace: bounding ? 2.2 : 1)
                    if bounding && state == .walk { running = true }
                }
            }
        }
        if let screen = screens.first(where: { $0.contains(position) }) ?? screens.min(by: {
            abs(($0.minX + $0.maxX) / 2 - position.x) < abs(($1.minX + $1.maxX) / 2 - position.x)
        }) {
            let leftContinues = screens.contains { $0 != screen && $0.contains(Point(screen.minX - 1, position.y)) }
            let rightContinues = screens.contains { $0 != screen && $0.contains(Point(screen.maxX + 1, position.y)) }
            position.x = min(max(position.x, screen.minX + (leftContinues ? 0 : 12)), screen.maxX - (rightContinues ? 0 : 12))
            if position.y < screen.minY {
                position.y = screen.minY; velocity = Point(0, 0)
            }
            if support == nil { position.y = min(position.y, screen.maxY - 32) }
        }
    }

    /// This display's floor, when the pet has ended up beneath it (e.g. let go of the pointer down by the Dock).
    /// Without this it would sit in the Dock strip, falling forever.
    func floorBelow(surfaces: [Surface], screens: [Rect]) -> Surface? {
        guard let screen = screens.first(where: { $0.contains(position) }) else { return nil }
        return surfaces.first {
            $0.kind == .floor && $0.supports(position.x) && position.y < $0.y &&
                $0.y >= screen.minY && $0.y <= screen.maxY && $0.left >= screen.minX - 1 && $0.right <= screen.maxX + 1
        }
    }

    private mutating func tendHome(_ home: DesktopHome, dt: Double, wallDT: Double, still: Bool) -> Bool {
        if homeActivity == .exploring {
            guard state != .climb, !(state == .react && actionRemaining > 0),
                  care.isHungry || care.foodInBowl else { return false }
            homeActivity = .goingToBowl
        }
        if homeActivity == .eating && position != Point(home.diningX, home.floor.y) { homeActivity = .goingToBed }
        let toBed = homeActivity == .goingToBed || homeActivity == .napping
        let goal = toBed ? home.pillowX : home.diningX
        if position != Point(goal, home.floor.y) {
            homeActivity = toBed ? .goingToBed : .goingToBowl
            stepHome(to: goal, home: home, dt: dt, still: still)
            return true
        }
        support = home.floor; direction = 1
        switch homeActivity {
        case .goingToBowl, .waiting:
            if care.foodInBowl {
                care.eat(); homeActivity = .eating; homeTime = 2
                change(.react, .feed)
            } else { homeActivity = .waiting; change(.sit, .sit) }
        case .eating:
            change(.react, .feed); homeTime -= wallDT
            if homeTime <= 0 { homeActivity = .goingToBed }
        case .goingToBed:
            homeActivity = .napping; homeTime = 18; change(.sleep, .sleep)
        case .napping:
            change(.sleep, .sleep); homeTime -= wallDT
            if homeTime <= 0 { homeActivity = .exploring; change(.idle, .stretch) }
        case .exploring: break
        }
        return true
    }

    private mutating func stepHome(to goal: Double, home: DesktopHome, dt: Double, still: Bool) {
        climbTarget = nil
        if still { perch(on: home.floor, x: goal); return }
        guard let surface = support else { return }
        if surface.kind != .floor {
            let right = abs(surface.right - goal) < abs(surface.left - goal)
            let edge = right ? surface.right : surface.left
            if surface.kind == .window && abs(position.x - edge) > 1 {
                walk(toward: edge, dt: dt)
            } else {
                // Start just below this ledge so gravity can catch the next one on the way down.
                support = nil; position.y -= 1; velocity = Point(0, 0)
                change(.fall, .fall)
            }
            return
        }
        let onHomeScreen = surface.id == home.floor.id
        let headingRight = home.origin.x > (surface.left + surface.right) / 2
        let stop = onHomeScreen ? goal : (headingRight ? surface.right - 1 : surface.left + 1)
        walk(toward: stop, dt: dt)
        if !onHomeScreen && position.x == stop {
            // Offset and stacked displays need an explicit passage between their safe floors.
            perch(on: home.floor, x: headingRight ? home.floor.left + 2 : home.floor.right - 2)
        }
    }
    private mutating func walk(toward x: Double, dt: Double) {
        let distance = x - position.x
        guard distance != 0 else { return }
        direction = distance > 0 ? 1 : -1
        position.x = abs(distance) <= 145 * dt ? x : position.x + direction * 145 * dt
        change(.walk, .walk)
    }
}
