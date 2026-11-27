import XCTest
@testable import PerchCore

final class CursorPlayTests: XCTestCase {
    let screen = Rect(0, 0, 1400, 900)
    let floor = Surface(id: "floor", left: 0, right: 1400, y: 0, kind: .floor)
    let day = Rhythm(hour: 15, quietEnabled: false)
    let window = DesktopWindow(id: 9, bounds: Rect(300, 0, 700, 600), pid: 77)
    var top: Surface { Surfaces.build(windows: [window], screens: [screen], visible: [screen]).first { $0.windowID == 9 }! }

    private func panda(at x: Double = 600) -> PetEngine {
        var pet = PetEngine(position: Point(x, 0))
        pet.agile = true
        pet.mischief = Mischief(play: false, chew: false, cursor: true)
        pet.perch(on: floor, x: x)
        return pet
    }

    /// Ticks with the pointer resting at `cursor` until the panda is hanging from it.
    private func hangOn(_ pet: inout PetEngine, cursor: Point) -> Bool {
        for _ in 0..<(30 * 40) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
            if pet.holdingCursor { return true }
        }
        return false
    }

    func testRedPandaStalksALingeringPointerGrabsItRidesAlongAndAShakeDropsIt() {
        var pet = panda()
        var cursor = Point(780, 115)
        var stalked = false, swiped = false
        for _ in 0..<(30 * 40) where !pet.holdingCursor {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
            if pet.running { stalked = true }
            if pet.trickPose == .pounce { swiped = true }
            XCTAssertNotEqual(pet.trickPose, .grab, "never stands up")
        }
        XCTAssertTrue(stalked, "runs over to the pointer")
        XCTAssertTrue(swiped, "crouches for a pounce before it grabs")
        XCTAssertTrue(pet.holdingCursor, "grabs a pointer that lingers nearby")
        XCTAssertEqual(pet.trickPose, .hang)
        for _ in 0..<10 { pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor) }
        XCTAssertEqual(pet.position, cursor, "leaps up and gets its teeth on the pointer's tip")

        // Sticky: a brisk straight move (1,500 pt/s) carries it along rather than shaking it off.
        for _ in 0..<12 {
            cursor.x += 50; cursor.y += 6
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
            XCTAssertTrue(pet.holdingCursor, "holds on through an ordinary move")
            XCTAssertEqual(pet.position, cursor, "rides exactly on the pointer's tip")
        }
        XCTAssertLessThan(pet.hangSwing, 0, "swings out behind a pointer moving right")

        // A real shake (quick back-and-forth) drops it, and it falls back to the floor.
        for i in 0..<15 where pet.holdingCursor {
            cursor.x += i % 2 == 0 ? 60 : -60
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
        }
        XCTAssertFalse(pet.holdingCursor, "shaken loose")
        XCTAssertEqual(pet.state, .fall)
        for _ in 0..<90 { pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor) }
        XCTAssertEqual(pet.support?.kind, .floor)
    }

    func testItLetsGoOnItsOwnAndPickingItUpOrBedtimeEndsThePlay() {
        var pet = panda()
        XCTAssertTrue(hangOn(&pet, cursor: Point(760, 115)))
        var held = 0
        while pet.holdingCursor && held < 30 * 30 {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: Point(760, 115))
            held += 1
        }
        XCTAssertGreaterThan(held, 30 * 5, "hangs on for a while")
        XCTAssertLessThan(held, 30 * 17, "gets bored and drops off by itself")

        var picked = panda()
        XCTAssertTrue(hangOn(&picked, cursor: Point(760, 115)))
        picked.hold(at: Point(500, 300))
        XCTAssertFalse(picked.holdingCursor); XCTAssertEqual(picked.state, .held)

        var sleepy = panda()
        XCTAssertTrue(hangOn(&sleepy, cursor: Point(760, 115)))
        sleepy.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: Rhythm(hour: 15, idleSeconds: 400, quietEnabled: false),
                    cursor: Point(760, 115))
        XCTAssertFalse(sleepy.holdingCursor, "lets go when it's time to rest")
    }

    func testALowPointerGetsBattedRatherThanRidden() {
        var pet = panda()
        var batted = false
        for _ in 0..<(30 * 30) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: Point(760, 30))
            if pet.trickPose == .pounce { batted = true }
            XCTAssertNotEqual(pet.trickPose, .grab, "never stands up")
            XCTAssertFalse(pet.holdingCursor, "never dangles below the floor it stands on")
        }
        XCTAssertTrue(batted)
    }

    func testLettingGoDownByTheDockLandsOnTheFloorInsteadOfFallingForever() {
        // The floor sits above a Dock strip, as on most Macs.
        let raised = Surface(id: "floor", left: 0, right: 1400, y: 70, kind: .floor)
        var pet = PetEngine(position: Point(600, 70))
        pet.agile = true
        pet.mischief = Mischief(cursor: true)
        pet.perch(on: raised, x: 600)
        var cursor = Point(760, 190)
        for _ in 0..<(30 * 40) where !pet.holdingCursor {
            pet.tick(dt: 1.0 / 30, surfaces: [raised], screens: [screen], rhythm: day, cursor: cursor)
        }
        XCTAssertTrue(pet.holdingCursor)
        // Carried right down over the Dock, then shaken off there.
        for _ in 0..<20 {
            cursor.y = max(80, cursor.y - 8)
            pet.tick(dt: 1.0 / 30, surfaces: [raised], screens: [screen], rhythm: day, cursor: cursor)
        }
        for i in 0..<15 where pet.holdingCursor {
            cursor.x += i % 2 == 0 ? 60 : -60
            pet.tick(dt: 1.0 / 30, surfaces: [raised], screens: [screen], rhythm: day, cursor: cursor)
        }
        XCTAssertFalse(pet.holdingCursor)
        for _ in 0..<60 { pet.tick(dt: 1.0 / 30, surfaces: [raised], screens: [screen], rhythm: day, cursor: nil) }
        XCTAssertEqual(pet.support?.id, "floor")
        XCTAssertEqual(pet.position.y, 70)
    }

    func testItEatsTheBambooOnThePointerFromTheBottomUpThenHopsOffHappyAndItGrowsBack() {
        var pet = panda()
        pet.bambooPointer = true
        let tip = Point(760, 200), scale = 3.0
        func target() -> Point { Bamboo.end(tip: tip, remaining: pet.bamboo, scale: scale) }
        for _ in 0..<(30 * 40) where !pet.holdingCursor {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: target())
        }
        XCTAssertTrue(pet.holdingCursor, "grabs the bottom of the stalk")
        var ends: [Double] = [], lengths: [Int] = []
        var ticks = 0
        while pet.holdingCursor && ticks < 30 * 20 {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: target())
            if pet.holdingCursor { ends.append(pet.position.y); lengths.append(Bamboo.pixels(remaining: pet.bamboo)) }
            ticks += 1
        }
        XCTAssertFalse(pet.holdingCursor)
        XCTAssertEqual(pet.bamboo, 0, "ate the whole stalk")
        XCTAssertGreaterThan(ticks, 30 * 8); XCTAssertLessThan(ticks, 30 * 12)
        XCTAssertEqual(lengths.first, Bamboo.fullLength); XCTAssertEqual(lengths.last, 1)
        XCTAssertGreaterThan(ends.last!, ends.first!, "climbs up the stalk as it eats it")
        var happy = false
        for _ in 0..<90 {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: target())
            happy = happy || pet.action == .pet
        }
        XCTAssertTrue(happy, "lands content")
        XCTAssertEqual(pet.support?.kind, .floor)
        // A stub isn't worth chasing; once it has grown back, it is.
        for _ in 0..<(30 * 20) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: target())
            XCTAssertTrue(pet.cursorPlay == nil || pet.bamboo >= 0.6)
        }
        for _ in 0..<(30 * 60) { pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: nil) }
        XCTAssertEqual(pet.bamboo, 1, "grows back")
    }

    func testTheBambooHangsFromThePointerTipAndItsEndIsWherePawsAndTeethGo() {
        let tip = Point(500, 400)
        let frame = Bamboo.frame(tip: tip, scale: 3)
        XCTAssertEqual(frame.x + Bamboo.centerX * 3, tip.x, "stalk centred under the tip")
        XCTAssertEqual(frame.maxY - 1.5 * 3, tip.y, accuracy: 0.001, "its top end is on the tip")
        XCTAssertEqual(Bamboo.end(tip: tip, remaining: 1, scale: 3).y, tip.y - 21 * 3, accuracy: 0.001, "centre of its 22nd pixel")
        XCTAssertEqual(Bamboo.pixels(remaining: 0.5), 11); XCTAssertEqual(Bamboo.pixels(remaining: 0), 0)
        for length in 0...Bamboo.fullLength {
            let art = Bamboo.art(length: length)
            for x in 0..<art.width { XCTAssertEqual(art[x, 0], "."); XCTAssertEqual(art[x, art.height - 1], ".") }
            for y in 0..<art.height { XCTAssertEqual(art[0, y], "."); XCTAssertEqual(art[art.width - 1, y], ".") }
            XCTAssertEqual((0..<art.height).last { art[9, $0] != "." } ?? 0, length, "stalk is \(length) pixels long")
        }
    }

    func testItGoesAfterThePointerAnywhereOnItsDisplayUpAWindowsSideAndLeapsForIt() {
        // Half-size panda, pointer resting on a window's face 800 points away, near its right side.
        var pet = PetEngine(position: Point(100, 0))
        pet.agile = true; pet.bodyHalfWidth = 24; pet.muzzleReach = 21
        pet.mischief = Mischief(cursor: true)
        pet.perch(on: floor, x: 100)
        let cursor = Point(900, 420)
        var clung = false, ticks = 0
        while !pet.holdingCursor && ticks < 30 * 60 {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window], cursor: cursor)
            if let grip = pet.cling {
                clung = true
                XCTAssertEqual(grip.side, .right, "up the side nearer the pointer")
                XCTAssertEqual(pet.position.x, window.bounds.maxX, accuracy: 0.01, "on the edge, never the face")
            }
            ticks += 1
        }
        XCTAssertTrue(clung, "climbs the window's side toward it")
        XCTAssertTrue(pet.holdingCursor, "and gets it")
        XCTAssertLessThan(ticks, 30 * 40)
    }

    func testAPointerFarAcrossABigWindowsFaceIsNotWorthFutileLeaps() {
        let big = DesktopWindow(id: 5, bounds: Rect(200, 0, 1000, 600), pid: 7)
        let bigTop = Surfaces.build(windows: [big], screens: [screen], visible: [screen]).first { $0.windowID == 5 }!
        var pet = PetEngine(position: Point(1250, 0))
        pet.agile = true; pet.bodyHalfWidth = 24; pet.muzzleReach = 21
        pet.mischief = Mischief(cursor: true)
        pet.perch(on: floor, x: 1250)
        var leaps = 0, wasLeaping = false
        for _ in 0..<(30 * 30) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, bigTop], screens: [screen], rhythm: day, windows: [big], cursor: Point(700, 350))
            if pet.trickPose == .leap && !wasLeaping { leaps += 1 }
            wasLeaping = pet.trickPose == .leap
        }
        XCTAssertLessThanOrEqual(leaps, 1, "out of reach in the middle of the window: it gives up rather than leaping again and again")
    }

    func testItLeapsToSnatchAPointerAboveWhatItCanReachStanding() {
        var pet = PetEngine(position: Point(500, 0))
        pet.agile = true; pet.bodyHalfWidth = 24; pet.muzzleReach = 21
        pet.mischief = Mischief(cursor: true)
        pet.perch(on: floor, x: 500)
        // Above what it can reach standing, within a leap of a little over twice its height.
        let cursor = Point(620, 115)
        var leapt = false
        for _ in 0..<(30 * 30) where !pet.holdingCursor {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
            leapt = leapt || pet.trickPose == .leap
        }
        XCTAssertTrue(leapt)
        XCTAssertTrue(pet.holdingCursor, "snatched it in mid-air")
    }

    func testShakenOffItComesBackForMoreAfterABreather() {
        var pet = panda()
        var cursor = Point(760, 115)
        XCTAssertTrue(hangOn(&pet, cursor: cursor))
        for i in 0..<15 where pet.holdingCursor {
            cursor.x += i % 2 == 0 ? 60 : -60
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
        }
        XCTAssertFalse(pet.holdingCursor)
        var quiet = 0, back = false
        for _ in 0..<(30 * 30) where !back {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
            if pet.cursorPlay == nil { quiet += 1 } else { back = true }
        }
        XCTAssertTrue(back, "keeps trying")
        XCTAssertGreaterThan(quiet, 30 * 5, "after a few seconds' breather")
    }

    func testAChaseStartedOnAWindowSideLeapsOffItAndSnatchesThePointer() {
        var pet = PetEngine(position: Point(996, top.y))
        pet.agile = true; pet.bodyHalfWidth = 24; pet.muzzleReach = 21
        pet.mischief = Mischief(cursor: true)
        pet.perch(on: top, x: 996)
        XCTAssertTrue(pet.startEdgeClimb(surfaces: [floor, top], windows: [window]))
        let cursor = Point(1030, 330)
        for _ in 0..<(30 * 30) where !pet.holdingCursor {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window], cursor: cursor)
        }
        XCTAssertTrue(pet.holdingCursor, "climbs down the side, leaps and grabs it")
    }

    func testATopEdgeErrandFromTheFloorGoesUpTheNearerSideAndOverTheTop() {
        var climber = PetEngine(position: Point(600, 0))
        climber.agile = true; climber.bodyHalfWidth = 24; climber.muzzleReach = 21
        climber.perch(on: floor, x: 600)
        climber.errand = Errand(target: Point(800, top.y), until: 30)
        var mounted = false, drops = 0, wasClinging = false
        for _ in 0..<(30 * 30) where !mounted {
            climber.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
            if let grip = climber.cling { XCTAssertEqual(grip.side, .right, "the side nearer where it's going") }
            if wasClinging && climber.cling == nil && climber.support == nil && climber.climbTarget == nil { drops += 1 }
            wasClinging = climber.cling != nil
            mounted = climber.support?.windowID == window.id
        }
        XCTAssertTrue(mounted, "up the side and over the top to the edge it was heading for")
        XCTAssertEqual(drops, 0, "no dropping off and climbing back on")
    }

    func testOnlyALivelyRedPandaWithCursorPlayOnChasesThePointer() {
        var dog = PetEngine(position: Point(600, 0))
        dog.mischief = Mischief(cursor: true)
        dog.perch(on: floor, x: 600)
        var off = panda(); off.mischief = Mischief()
        var calm = panda(), still = panda()
        for _ in 0..<(30 * 40) {
            dog.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: Point(760, 115))
            off.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: Point(760, 115))
            calm.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: Rhythm(hour: 15, calm: true, quietEnabled: false),
                      cursor: Point(760, 115))
            still.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, reduceMotion: true, cursor: Point(760, 115))
            for pet in [dog, off, calm, still] { XCTAssertNil(pet.cursorPlay) }
        }
    }

    func testItLivesItsOwnLifeAndOnlyChasesThePointerNowAndThenWithoutStandingUp() {
        var pet = panda()
        var chases = 0, wasChasing = false, ticks = 0
        for i in 0..<(30 * 60 * 5) {
            // A pointer resting in reach, then whizzing right past it now and then.
            let whizz = i % 300 < 20
            let cursor = whizz ? Point(pet.position.x - 400 + Double(i % 300) * 40, 50) : Point(760, 115)
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
            XCTAssertNotEqual(pet.trickPose, .grab, "it never rears up on its hind legs")
            let chasing = pet.cursorPlay != nil
            if chasing && !wasChasing { chases += 1 }
            if chasing { ticks += 1 }
            wasChasing = chasing
        }
        XCTAssertGreaterThan(chases, 0, "it does go after the pointer for fun")
        XCTAssertLessThanOrEqual(chases, 8, "but only now and then over five minutes")
        XCTAssertLessThan(Double(ticks) / Double(30 * 60 * 5), 0.5, "and spends most of its time on its own business")
    }

    func testRedPandasHoldOnThroughABriskWindowDragThatThrowsADogOff() {
        func ride(_ agile: Bool) -> PetState {
            var pet = PetEngine(position: Point(600, top.y))
            pet.agile = agile
            pet.perch(on: top, x: 600)
            var moved = window; moved.bounds.x += 30
            let movedTop = Surfaces.build(windows: [moved], screens: [screen], visible: [screen]).first { $0.windowID == 9 }!
            pet.tick(dt: 1.0 / 30, surfaces: [floor, movedTop], screens: [screen], rhythm: day, surfaceDT: 1.0 / 30, windows: [moved])
            return pet.state
        }
        XCTAssertEqual(ride(false), .fall, "900 pt/s slides a dog off")
        XCTAssertNotEqual(ride(true), .fall, "a red panda grips on")
    }

    func testAFallingRedPandaGrabsTheSideOfAWindowItFallsPastButADogDoesNot() {
        var caught: UInt32?
        var pet = panda()
        let past = 300 - 48 * 0.4
        for _ in 0..<8 where caught == nil {
            pet.hold(at: Point(past, 520)); pet.release()
            for _ in 0..<60 where caught == nil {
                pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, windows: [window])
                caught = pet.cling?.window
            }
        }
        XCTAssertEqual(caught, 9, "sticky paws catch the window it falls past")
        XCTAssertEqual(pet.cling?.side, .left); XCTAssertEqual(pet.position.x, 300, "by its edge")
        XCTAssertGreaterThan(pet.position.y, 300, "catches on partway down rather than at the bottom")

        var dog = PetEngine(position: Point(600, 0))
        for _ in 0..<8 {
            dog.hold(at: Point(600, 520)); dog.release()
            for _ in 0..<60 {
                dog.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, windows: [window])
                XCTAssertNil(dog.cling)
            }
        }
    }

    func testRedPandaClimbsAndBacksDownWindowSidesAndWashesSnacksAndDrapesLikeTheRealThing() {
        var pet = PetEngine(position: Point(600, top.y))
        pet.agile = true
        pet.perch(on: top, x: 600)
        var poses = Set<SpecialPose>(), walking = 0
        let ticks = 30 * 60 * 10
        for _ in 0..<ticks {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
            if let pose = pet.trickPose { poses.insert(pose) }
            if pet.state == .walk || pet.cling != nil || pet.state == .climb { walking += 1 }
            if let grip = pet.cling { XCTAssertEqual(pet.trickPose, PetEngine.pose(for: grip)) }
        }
        XCTAssertTrue(poses.isSuperset(of: [.scale, .scaleDown, .groom, .nibble]), "\(poses)")
        XCTAssertGreaterThan(Double(walking) / Double(ticks), 0.5, "still on the move most of the time")

        var sleeper = PetEngine(position: Point(600, top.y))
        sleeper.agile = true
        sleeper.perch(on: top, x: 600)
        let night = Rhythm(hour: 23, quietStart: 22, quietEnd: 7)
        sleeper.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: night, windows: [window])
        XCTAssertEqual(sleeper.state, .sleep); XCTAssertEqual(sleeper.trickPose, .drape, "sprawls over a window edge to sleep")
        sleeper.perch(on: floor, x: 100)
        sleeper.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: night, windows: [window])
        XCTAssertEqual(sleeper.state, .sleep); XCTAssertEqual(sleeper.trickPose, .sprawl, "sprawls out on the floor")
    }
}
