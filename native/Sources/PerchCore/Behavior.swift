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
    var nextChoice: Double = 2
    private var random: UInt64 = 0x5045524348
    var overrideUntil = 0.0
    var clock = 0.0
    var actionRemaining = 0.0
    var climbTarget: Surface?
    private var climbFrom = Point(0, 0)
    private var nextTug = 30.0
    /// Visiting its tree: heading there, or resting in it.
    public internal(set) var treeActivity: TreeActivity = .exploring
    var treeVisitUntil = 0.0
    var treeClimb: TreeClimb?
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
    /// Climbs window sides and hangs from bottom edges as well as walking top edges. The app turns this on for its
    /// red panda.
    public var agile = false
    public internal(set) var cling: Cling?
    var lastClingOrigin: Point?
    /// How far it has climbed, in art pixels, which picks the stride frame; and whether it's holding still.
    public internal(set) var climbed = 0.0
    public internal(set) var climbHolding = false
    /// Swinging round a bottom corner: where it was, and when, so the move eases rather than jumps.
    var turnFrom: (from: Point, at: Double)?
    /// Swinging round a bottom corner right now.
    public var turning: Bool { turnFrom != nil }
    var nextScramble = 4.0
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
    var nextCursorPlay = 2.0, nextStartle = 0.0, nextChaseClimb = 0.0, leapUntil = 0.0, nextLeap = 0.0
    /// Chases in a row that couldn't reach the pointer; after a couple it explores for a while instead.
    var chaseMisses = 0
    var lounge: Lounge?
    /// Somewhere it has decided to go: a spot on a window, a window's top edge, or across the floor.
    var errand: Errand?
    /// The pointer carries a bamboo stalk: the panda plays with its bottom end and eats it while it hangs on.
    public var bambooPointer = false
    /// How much of the stalk is left (1 is whole). It grows back while the panda isn't eating it.
    public internal(set) var bamboo = 1.0
    /// Finished a whole stalk: lands happy.
    var sated = false
    var zoomUntil = 0.0
    /// While falling: the window it just left, whether it will try to grab a window's side, and for how long it has fallen.
    var fallFrom: UInt32?
    var fallGrab: Bool?
    var fallTime = 0.0
    /// In the air on purpose, and the window it means to land on, if any.
    var leaping = false
    var leapCatch: UInt32?
    public init(position: Point) { self.position = position }
    public mutating func setBed(_ value: Bool) {
        treeActivity = .exploring; treeClimb = nil; climbTarget = nil; endTrick(); cling = nil; lastClingOrigin = nil
        if holdingCursor { dropFromCursor() }
        cursorPlay = nil; lounge = nil; errand = nil; leaping = false
        bed = value
        if value { change(.sleep, .sleep) } else { overrideUntil = clock + 300; change(support == nil ? .fall : .idle, support == nil ? .fall : .idle) }
    }
    public mutating func hold(at point: Point) {
        endTrick(); cling = nil; lastClingOrigin = nil; treeActivity = .exploring; treeClimb = nil; climbTarget = nil
        if cursorPlay != nil { endCursorPlay(); cursorPlay = nil }
        lounge = nil; errand = nil; hangSwing = 0; leaping = false
        position = point; support = nil; velocity = Point(0, 0); change(.held, .held)
    }
    public mutating func drag(to point: Point) { if state == .held { position = point } }
    public mutating func release() {
        if holdingCursor { cursorPlay = nil; hangSwing = 0 }
        fallFrom = nil; fallGrab = nil; fallTime = 0; leaping = false; leapCatch = nil
        cling = nil; lastClingOrigin = nil; treeActivity = .exploring; treeClimb = nil; climbTarget = nil
        support = nil; velocity = Point(0, 0); change(.fall, .fall)
    }
    public mutating func react(_ selected: Action = .pet) {
        // Holding on to a window's edge or the trunk: enjoy the attention without letting go.
        guard state != .held, cling == nil, treeClimb == nil, !holdingCursor else { overrideUntil = clock + 300; return }
        endTrick(); lounge = nil; errand = nil
        if cursorPlay != nil { endCursorPlay() }
        bed = false; overrideUntil = clock + 300
        change(.react, selected); actionRemaining = 2
    }
    public mutating func relocate(_ point: Point) { position = point; release(); bed = false }
    public mutating func perch(on surface: Surface, x: Double) {
        climbTarget = nil; treeClimb = nil; leaping = false
        support = surface; position = Point(x, surface.y); velocity = Point(0, 0); change(.sit, .sit)
    }
    public mutating func climb(to surface: Surface) {
        endTrick(); cling = nil; lastClingOrigin = nil; treeActivity = .exploring; treeClimb = nil; bed = false
        overrideUntil = clock + 300
        if holdingCursor { dropFromCursor() }
        cursorPlay = nil; lounge = nil; errand = nil
        beginClimb(to: surface)
    }
    /// Off to its tree now (from the menu), staying a while.
    public mutating func goToTree() {
        guard state != .held else { return }
        if bed { setBed(false) }
        if cling != nil { letGo() }
        overrideUntil = clock + 300
        treeActivity = .exploring
        visitTree(for: 25)
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
        nextTug = 30
        support = nil; change(.climb, .climb); elapsed = 0
    }
    mutating func change(_ newState: PetState, _ newAction: Action) {
        if state != newState || action != newAction { elapsed = 0 }
        state = newState; action = newAction
    }
    mutating func pick() -> Double {
        random = random &* 6364136223846793005 &+ 1
        return Double(random >> 32) / Double(UInt32.max)
    }
    public mutating func tick(dt rawDT: Double, surfaces baseSurfaces: [Surface], screens: [Rect], rhythm: Rhythm,
                              surfaceDT: Double? = nil, tree: TreeHome? = nil, reduceMotion: Bool = false,
                              windows: [DesktopWindow] = [], cursor: Point? = nil) {
        let dt = max(0, min(rawDT.isFinite ? rawDT : 0, 0.1))
        let wallDT = max(0, min(rawDT.isFinite ? rawDT : 0, 1))
        clock += wallDT; elapsed += wallDT; actionRemaining -= wallDT
        running = false; trickPose = nil; gentle = rhythm.calm
        // The tree's branch is one more ledge to stand on.
        let surfaces = tree.map { baseSurfaces + [$0.branch] } ?? baseSurfaces
        tickBall(dt: dt, surfaces: surfaces, screens: screens, windows: windows)
        trackCursor(cursor, dt: wallDT)
        if !holdingCursor { bamboo = min(1, bamboo + wallDT / 40) }
        guard state != .held else { return }
        let resting = (rhythm.quiet || rhythm.idleSeconds >= 300) && clock >= overrideUntil
        if tree == nil { treeActivity = .exploring; treeClimb = nil }
        let unplayful = bed || reduceMotion || !agile || !mischief.cursor || gentle || resting || treeActivity != .exploring
        if holdingCursor {
            tendHang(cursor, dt: dt, restless: unplayful)
            if holdingCursor { return }
        } else if cursorPlay != nil && unplayful { endCursorPlay() }
        if bed {
            endTrick(); change(.sleep, .sleep)
            if agile && (support?.kind == .window || support?.kind == .branch) { trickPose = .drape }
            return
        }
        // Bedtime (or a long idle) sends it to its tree.
        if resting, let tree, treeActivity == .exploring, support?.id != tree.branch.id { visitTree(for: 0) }
        if let tree, tendTreeClimb(tree, dt: dt, still: reduceMotion) { return }
        if cling != nil {
            let restless = resting || reduceMotion || !agile || treeActivity != .exploring
            if cursorPlay == nil && errand == nil && !restless { _ = noticeCursor(cursor, screens: screens, dt: dt) }
            if let play = cursorPlay {
                // A chase noticed up here gets going after its look, as it does on a ledge.
                if case .notice(let until) = play.phase, clock >= until { cursorPlay?.phase = .stalk }
                if restless || clock > play.until { endCursorPlay(missed: true) }
                else if let cursor {
                    let head = reachPoint
                    if hypot(cursor.x - head.x, cursor.y - head.y) < bodyHalfWidth * 0.9 { grabCursor(cursor); return }
                    aimCling(at: cursor, windows: windows, surfaces: surfaces, pace: 2.6, head: true)
                } else { endCursorPlay() }
            } else if let job = errand {
                if restless || clock > job.until { errand = nil }
                // It steers its head to the spot, so that's where it has arrived.
                else if hypot(job.target.x - reachPoint.x, job.target.y - reachPoint.y) < bodyHalfWidth { errand = nil }
                else { aimCling(at: job.target, windows: windows, surfaces: surfaces, pace: 1.6, head: false) }
            }
            tendCling(dt: dt, surfaceDT: surfaceDT, surfaces: surfaces, windows: windows, restless: restless)
            return
        }
        if state == .climb, let target = climbTarget {
            guard let current = surfaces.first(where: {
                target.windowID != nil ? $0.windowID == target.windowID && $0.supports((target.left + target.right) / 2) : $0.id == target.id
            }) else { release(); return }
            let lo = current.left + min(20, (current.right - current.left) / 2), hi = current.right - min(20, (current.right - current.left) / 2)
            let x = min(max(climbFrom.x, lo), max(lo, hi))
            let tug = (target.kind == .window || target.kind == .branch) && climbFrom.y < current.y - hangDepth
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
                nextChoice = current.kind == .menu ? 6 + pick() * 4 : 0.6 + pick()
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
                // Red pandas hold on through a brisk drag; only a flung window throws them off.
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
            if tendAirborne(cursor: cursor, surfaces: surfaces, windows: windows, dt: dt,
                            sticky: trick == nil && treeActivity == .exploring && !resting && !reduceMotion) { return }
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
                let leapt = leaping
                leaping = false; leapCatch = nil
                if let tree, landing.id == tree.branch.id, treeActivity == .goingToTree { treeActivity = .inTree }
                if sated { sated = false; change(.react, .pet); actionRemaining = 1.8 }
                else if leapt || cursorPlay != nil || errand != nil { change(.idle, .idle); actionRemaining = 0 }
                else { change(.react, .shake); actionRemaining = 0.8 }
            }
        } else if riding {
            change(.ride, .ride); elapsed = 0
        } else if state == .ride && elapsed > 0.18 { change(.idle, .idle) }
        if support != nil && !riding {
            if tree != nil && treeActivity != .exploring { if trick != nil { endTrick() }; errand = nil }
            if let tree, tendTree(tree, surfaces: surfaces, dt: dt, resting: resting, still: reduceMotion) { return }
            if cursorPlay != nil, let surface = support, !(state == .react && action == .shake && actionRemaining > 0),
               tendCursorChase(cursor, on: surface, surfaces: surfaces, windows: windows, screens: screens, dt: dt) { return }
            if trick != nil {
                if resting { endTrick() }
                else if !(state == .react && action == .shake && actionRemaining > 0),
                        tendTrick(dt: dt, surfaces: surfaces, windows: windows) { return }
            }
            if let pose = lounge {
                if clock < pose.until && !resting && !reduceMotion {
                    // Even mid-wash, a pointer can steal its attention.
                    if pose.pose != .grab && noticeCursor(cursor, screens: screens, dt: dt) { return }
                    trickPose = lounge?.pose ?? pose.pose; change(.idle, pose.pose == .grab ? .look : .sit)
                    return
                }
                lounge = nil; nextChoice = 0; elapsed = 0
            }
            if resting {
                change(.sleep, .sleep)
            } else if state == .sleep { change(.idle, .stretch); actionRemaining = 1.5 }
            // Warm and up high: sprawled over the edge with its legs dangling, as red pandas sleep on branches.
            if state == .sleep && agile && (support?.kind == .window || support?.kind == .branch) { trickPose = .drape }
            if state == .react || state == .climb {
                // A brief beat after a reaction, then back to exploring rather than idling out a stale timer.
                if actionRemaining <= 0 { change(.idle, .idle); nextChoice = 0.3 + pick() * 0.5 }
            } else if support?.kind == .menu {
                if elapsed >= nextChoice { support = nil; velocity = Point(0, 0); change(.fall, .fall) }
            } else if state != .sleep {
                if !rhythm.calm && !reduceMotion {
                    nextTug -= wallDT
                    if nextTug <= 0 {
                        nextTug = 20
                        if let target = windowToClimb(surfaces: surfaces, screens: screens, nearbyOnly: true) {
                            beginClimb(to: target); return
                        }
                    }
                }
                // Reduce Motion keeps the pet still; everything else explores.
                if reduceMotion { change(.sit, .sit) }
                else if noticeCursor(cursor, screens: screens, dt: dt) { return }
                else if let surface = support, tendErrand(on: surface, surfaces: surfaces, windows: windows, dt: dt) { return }
                else if elapsed >= nextChoice {
                    if choose(surfaces: surfaces, windows: windows, screens: screens, tree: tree) { return }
                }
                if state == .walk, let surface = support {
                    let bounding = clock < zoomUntil
                    wander(on: surface, surfaces: surfaces, windows: windows, dt: dt, pace: bounding ? 2.2 : 1)
                    if bounding && state == .walk { running = true; if agile { trickPose = .run } }
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

    /// What to do next once a walk or pause is over. Red pandas spend most of it on the move: off on an errand
    /// across the desktop, up a window, or ambling along, with short pauses to sniff, wash or snack.
    /// Returns true when the choice took over this tick.
    private mutating func choose(surfaces: [Surface], windows: [DesktopWindow], screens: [Rect], tree: TreeHome?) -> Bool {
        let value = pick()
        elapsed = 0
        if !gentle {
            if mischief.play && clock >= nextPlay && value < 0.05 { startPlay(); return true }
            if mischief.chew && clock >= nextChew && value < 0.12 && startChew() { return true }
            if agile && value < 0.5 && startErrand(surfaces: surfaces, windows: windows, screens: screens, tree: tree) { return true }
            if agile && clock >= nextScramble && value < 0.66 && startEdgeClimb(surfaces: surfaces, windows: windows) {
                nextScramble = clock + 6 + pick() * 8; return true
            }
        }
        let pause = pick(), walk = gentle ? 0.5 : agile ? 0.6 : 0.70
        if pause < walk { change(.walk, .walk); if pick() < 0.35 { direction *= -1 } }
        else if agile && !gentle {
            // Short red panda pauses from zoo time budgets: a sniff, a face-wash, a snack, a sudden bound.
            if pause < 0.7 { change(.idle, .sniff) }
            else if pause < 0.8 { lounge = Lounge(pose: .groom, until: clock + 3 + pick() * 3); return true }
            else if pause < 0.89 { lounge = Lounge(pose: .nibble, until: clock + 4 + pick() * 3); return true }
            else if pause < 0.97 {
                zoomUntil = clock + 2 + pick() * 3; change(.walk, .walk)
                if pick() < 0.5 { direction *= -1 }
            } else { change(.sit, .sit) }
        }
        else if pause < walk + 0.10 { change(.idle, .sniff) }
        else if pause < walk + (gentle ? 0.40 : 0.19) { change(.sit, .sit) }
        else if pause < walk + (gentle ? 0.46 : 0.25) { change(.idle, .stretch) }
        else { change(.idle, .yawn) }
        nextChoice = state == .walk ? (gentle ? 4 + pick() * 5 : 3 + pick() * 4)
                                    : (gentle ? 4 + pick() * 5 : 1 + pick() * 1.5)
        return false
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

    /// Walk over to `goal` on `floor`, dropping off ledges and crossing displays on the way.
    mutating func stepHome(to goal: Double, floor: Surface, dt: Double, still: Bool) {
        climbTarget = nil
        if still { perch(on: floor, x: goal); return }
        guard let surface = support else { return }
        if surface.kind != .floor {
            let right = abs(surface.right - goal) < abs(surface.left - goal)
            let edge = right ? surface.right : surface.left
            if surface.kind != .menu && abs(position.x - edge) > 1 {
                walk(toward: edge, dt: dt)
            } else {
                // Start just below this ledge so gravity can catch the next one on the way down.
                support = nil; position.y -= 1; velocity = Point(0, 0)
                change(.fall, .fall)
            }
            return
        }
        let onHomeScreen = surface.id == floor.id
        let headingRight = goal > (surface.left + surface.right) / 2
        let stop = onHomeScreen ? goal : (headingRight ? surface.right - 1 : surface.left + 1)
        walk(toward: stop, dt: dt)
        if !onHomeScreen && position.x == stop {
            // Offset and stacked displays need an explicit passage between their safe floors.
            perch(on: floor, x: headingRight ? floor.left + 2 : floor.right - 2)
        }
    }
    private mutating func walk(toward x: Double, dt: Double) {
        let distance = x - position.x
        guard distance != 0 else { return }
        direction = distance > 0 ? 1 : -1
        position.x = abs(distance) <= 90 * dt ? x : position.x + direction * 90 * dt
        change(.walk, .walk); running = true
        if agile { trickPose = .run }
    }
}
