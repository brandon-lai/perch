import XCTest
@testable import PerchCore

final class NapTests: XCTestCase {
    let screen = Rect(0, 0, 1400, 900)
    let floor = Surface(id: "floor", left: 0, right: 1400, y: 0, kind: .floor)
    let day = Rhythm(hour: 15, quietEnabled: false)
    let window = DesktopWindow(id: 9, bounds: Rect(300, 0, 700, 600), pid: 77)
    func top(of window: DesktopWindow) -> Surface {
        Surfaces.build(windows: [window], screens: [screen], visible: [screen]).first { $0.windowID == window.id }!
    }

    private func panda(at x: Double, on surface: Surface) -> PetEngine {
        var pet = PetEngine(position: Point(x, surface.y))
        pet.agile = true; pet.bodyHalfWidth = 24; pet.muzzleReach = 21; pet.hangDepth = 25
        pet.perch(on: surface, x: x)
        return pet
    }

    /// Sleepy on a window's top edge: ticks until it's lying asleep there.
    private func asleepOnTheWindow() -> PetEngine {
        let top = top(of: window)
        var pet = panda(at: 600, on: top)
        pet.startNap()
        for _ in 0..<(30 * 10) where pet.state != .sleep {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
        }
        XCTAssertEqual(pet.state, .sleep)
        return pet
    }

    func testItRestsMostOfTheDayDrapedOverAWindowsTopEdgeLikeABranchBetweenShortSpellsOfExploring() {
        let top = top(of: window)
        var pet = panda(at: 600, on: top)
        pet.dozes = true
        pet.mischief = Mischief(cursor: true); pet.nextCursorPlay = 0
        let faraway = Point(1300, 850)
        var asleep = 0, naps = 0, wasAsleep = false, chasedInItsSleep = false, poses = Set<SpecialPose>(), actions = Set<Action>()
        let ticks = 30 * 60 * 30
        for _ in 0..<ticks {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window], cursor: faraway)
            if pet.state == .sleep {
                asleep += 1
                if !wasAsleep { naps += 1 }
                if pet.cursorPlay != nil { chasedInItsSleep = true }
                if let pose = pet.trickPose { poses.insert(pose) }
                if pet.support?.kind == .window { XCTAssertEqual(pet.trickPose, .drape, "draped over the edge, legs dangling") }
                XCTAssertEqual(pet.bubble, .zs)
            } else if wasAsleep { actions.insert(pet.action) }
            if pet.nap != nil, case .waking = pet.nap!.stage { actions.insert(pet.action); if let p = pet.trickPose { poses.insert(p) } }
            wasAsleep = pet.state == .sleep
        }
        XCTAssertGreaterThanOrEqual(naps, 2, "rests on and off through half an hour")
        XCTAssertTrue(poses.contains(.drape), "naps on a window's top edge, as if it were a branch")
        XCTAssertTrue(actions.contains(.stretch) && poses.contains(.groom), "wakes with a stretch and a wash")
        XCTAssertFalse(chasedInItsSleep, "leaves the pointer alone while it naps")
        let share = Double(asleep) / Double(ticks)
        XCTAssertGreaterThan(share, 0.6, "asleep most of the time"); XCTAssertLessThan(share, 0.9, "with spells of exploring")
    }

    func testPettingItInItsSleepMakesItSnuggleInAndADoubleClickWakesIt() {
        let top = top(of: window)
        var pet = asleepOnTheWindow()
        pet.nap?.until = pet.clock + 5
        pet.react(.pet)
        pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
        XCTAssertEqual(pet.state, .sleep, "petting doesn't wake it")
        XCTAssertEqual(pet.trickPose, .drapeSnuggle)
        XCTAssertEqual(pet.bubble, .heart)
        XCTAssertGreaterThanOrEqual(pet.nap!.until, pet.clock + 24.9, "and it dozes on a little longer")
        for _ in 0..<(30 * 3) { pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window]) }
        XCTAssertEqual(pet.trickPose, .drape, "settles back into sleep")

        pet.wakeUp()
        pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
        XCTAssertEqual(pet.action, .stretch, "wakes with a stretch")
        for _ in 0..<(30 * 7) { pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window]) }
        XCTAssertNil(pet.nap); XCTAssertNotEqual(pet.state, .sleep)
    }

    func testTheBambooHeldUnderItsNoseWakesItForASnackWhileThePointerAloneJustMakesItPeek() {
        let top = top(of: window)
        var pet = asleepOnTheWindow()
        pet.mischief = Mischief(cursor: true)
        // Only the pointer: it lifts its head and peeks, and sleeps on.
        for _ in 0..<(30 * 4) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window], cursor: pet.sleepingNose)
        }
        XCTAssertEqual(pet.state, .sleep); XCTAssertEqual(pet.trickPose, .drapeStir)
        // The bamboo: a sniff or two, and it's up after it.
        pet.bambooPointer = true
        var woke = 0.0
        for i in 0..<(30 * 4) where pet.cursorPlay == nil {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window], cursor: pet.sleepingNose)
            woke = Double(i + 1) / 30
        }
        XCTAssertNotNil(pet.cursorPlay, "goes for the bamboo")
        XCTAssertNil(pet.nap); XCTAssertNotEqual(pet.state, .sleep)
        XCTAssertGreaterThan(woke, 1.5, "after a sniff, not at once")
    }

    func testWithNoTreeAndNoWindowItCanReachItStillGetsItsRestOnTheFloor() {
        // A window floating well above the floor: out of a leap, and no side reaches down to it.
        let high = DesktopWindow(id: 5, bounds: Rect(300, 200, 700, 400), pid: 7)
        let surfaces = Surfaces.build(windows: [high], screens: [screen], visible: [screen])
        let ground = surfaces.first { $0.kind == .floor }!
        var pet = panda(at: 650, on: ground)
        pet.dozes = true
        var slept = false
        for _ in 0..<(30 * 60 * 4) where !slept {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: [screen], rhythm: day, windows: [high])
            if pet.nextChoice > 0 && pet.lounge == nil && pet.state == .idle { pet.nextChoice = 0 }
            slept = pet.state == .sleep
        }
        XCTAssertTrue(slept, "doesn't keep restarting a nap it can't get to")
        XCTAssertEqual(pet.support?.kind, .floor)
        XCTAssertEqual(pet.trickPose, .sprawl)
    }

    func testWokenByYouItStaysUpAWhileAndComesForTheBamboo() {
        let top = top(of: window)
        var pet = asleepOnTheWindow()
        pet.dozes = true; pet.mischief = Mischief(cursor: true); pet.bambooPointer = true
        let bamboo = Point(pet.position.x + 140, top.y + 30)
        pet.wakeUp()
        var came = false, napped = false
        for _ in 0..<(30 * 60) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window], cursor: bamboo)
            if pet.cursorPlay != nil { came = true }
            if pet.state == .sleep { napped = true }
        }
        XCTAssertTrue(came, "up, it comes to play with you")
        XCTAssertFalse(napped, "and stays up a while before resting again")
    }

    func testCarriedAsleepItDozesOnAndSetDownGentlyItNapsOnButADropFromHighWakesIt() {
        let top = top(of: window)
        var pet = asleepOnTheWindow()
        pet.hold(at: pet.position)
        pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
        XCTAssertEqual(pet.trickPose, .dozing, "dangling limp, still asleep")
        XCTAssertEqual(pet.bubble, .zs)
        pet.drag(to: Point(450, top.y + 20)); pet.release()
        for _ in 0..<(30 * 2) { pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window]) }
        XCTAssertEqual(pet.state, .sleep, "set down gently, it naps on")
        XCTAssertTrue(pet.napping); XCTAssertEqual(pet.trickPose, .drape)
        XCTAssertEqual(pet.position.x, 450, accuracy: 0.01)

        pet.hold(at: pet.position); pet.drag(to: Point(1200, 500)); pet.release()
        for _ in 0..<(30 * 3) { pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window]) }
        XCTAssertNotEqual(pet.state, .sleep, "dropped from high up, it wakes with a start")
        XCTAssertFalse(pet.napping)
    }

    func testItSleepsThroughAGentleDragOfItsWindowButAFlingWakesIt() {
        var pet = asleepOnTheWindow()
        var moved = window
        for _ in 0..<(30 * 2) {
            moved = DesktopWindow(id: 9, bounds: Rect(moved.bounds.x + 2, moved.bounds.y, 700, 600), pid: 77)
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top(of: moved)], screens: [screen], rhythm: day, windows: [moved])
            XCTAssertEqual(pet.state, .sleep, "sleeps on, carried along")
            XCTAssertTrue(pet.recentlyCarried)
        }
        XCTAssertEqual(pet.support?.windowID, 9)
        XCTAssertEqual(pet.trickPose, .drape)
        moved = DesktopWindow(id: 9, bounds: Rect(moved.bounds.x + 90, moved.bounds.y, 700, 600), pid: 77)
        pet.tick(dt: 1.0 / 30, surfaces: [floor, top(of: moved)], screens: [screen], rhythm: day, windows: [moved])
        XCTAssertNil(pet.nap, "a fling wakes it"); XCTAssertEqual(pet.state, .fall)
    }

    func testAskedToNapItClimbsItsTreeAndSleepsDrapedOnTheBranchUntilWoken() {
        let floor = Surfaces.build(windows: [], screens: [screen], visible: [screen]).first { $0.kind == .floor }!
        let tree = TreeHome(floor: floor, position: 0.7, scale: 1.5)
        var pet = panda(at: 200, on: floor)
        pet.takeNap()
        for _ in 0..<(30 * 60) where !(pet.state == .sleep && pet.support?.id == tree.branch.id) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, tree: tree)
        }
        XCTAssertEqual(pet.support?.id, tree.branch.id, "up in its tree")
        XCTAssertEqual(pet.trickPose, .drape)
        for _ in 0..<(30 * 60 * 10) { pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, tree: tree) }
        XCTAssertEqual(pet.state, .sleep, "a nap you asked for lasts until you wake it")
        pet.wakeUp()
        for _ in 0..<(30 * 40) where pet.support?.kind != .floor {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, tree: tree)
        }
        XCTAssertEqual(pet.support?.kind, .floor, "then climbs back down")
        XCTAssertNil(pet.nap)
    }

    func testHoweverATreeNapEndsItClimbsBackDownAndIsntSleepyAgainStraightAway() {
        let floor = Surfaces.build(windows: [], screens: [screen], visible: [screen]).first { $0.kind == .floor }!
        let tree = TreeHome(floor: floor, position: 0.7, scale: 1.5)
        func tick(_ pet: inout PetEngine, _ seconds: Double, _ rhythm: Rhythm, until done: (PetEngine) -> Bool = { _ in false }) {
            for _ in 0..<Int(seconds * 30) where !done(pet) {
                pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: rhythm, tree: tree)
            }
        }
        // You step away mid-nap: it sleeps on in the tree, then climbs down when you're back.
        var pet = panda(at: 200, on: floor)
        pet.takeNap()
        tick(&pet, 60, day) { $0.state == .sleep && $0.support?.id == tree.branch.id }
        tick(&pet, 60, Rhythm(hour: 15, idleSeconds: 400, quietEnabled: false))
        XCTAssertEqual(pet.state, .sleep); XCTAssertNil(pet.nap, "bedtime takes over from the nap")
        tick(&pet, 60, day) { $0.support?.kind == .floor }
        XCTAssertEqual(pet.support?.kind, .floor, "back down in the morning, not stuck in the tree")
        var napped = false
        for _ in 0..<(30 * 120) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, tree: tree)
            if pet.nap != nil { napped = true }
        }
        XCTAssertFalse(napped, "not sleepy again straight after a night's sleep")

        // Woken on its way up: it carries on rather than staying in the tree.
        var climber = panda(at: 200, on: floor)
        climber.takeNap()
        tick(&climber, 30, day) { $0.treeActivity == .inTree }
        climber.wakeUp()
        tick(&climber, 90, day) { $0.support?.kind == .floor && $0.treeActivity == .exploring }
        XCTAssertEqual(climber.treeActivity, .exploring)
        XCTAssertEqual(climber.support?.kind, .floor)
    }

    func testAtTheAppsSlowSleepingTickTheBambooStillWakesItAfterAboutTwoSeconds() {
        let top = top(of: window)
        var pet = asleepOnTheWindow()
        pet.mischief = Mischief(cursor: true); pet.bambooPointer = true
        var held = 0.0
        while pet.cursorPlay == nil && held < 10 {
            pet.tick(dt: 0.25, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window], cursor: pet.sleepingNose)
            held += 0.25
        }
        XCTAssertEqual(held, 2.25, accuracy: 0.26)
    }

    func testAskedToNapWithoutATreeItFindsAWindowTopOrSprawlsOutOnTheFloor() {
        let top = top(of: window)
        var pet = panda(at: 1200, on: floor)
        pet.takeNap()
        for _ in 0..<(30 * 90) where pet.state != .sleep {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
        }
        XCTAssertEqual(pet.state, .sleep)
        XCTAssertEqual(pet.support?.windowID, 9, "heads up onto a window's top to sleep")
        XCTAssertEqual(pet.trickPose, .drape)

        var floorSleeper = panda(at: 700, on: floor)
        floorSleeper.takeNap()
        for _ in 0..<(30 * 90) where floorSleeper.state != .sleep {
            floorSleeper.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day)
        }
        XCTAssertEqual(floorSleeper.state, .sleep)
        XCTAssertEqual(floorSleeper.trickPose, .sprawl, "with nowhere high, it sprawls out on the floor")
    }
}
