import XCTest
@testable import PerchCore

final class DesktopHomeTests: XCTestCase {
    let screens = [Rect(-640, 0, 640, 600), Rect(0, 140, 800, 600)]
    var floors: [Surface] { Surfaces.build(windows: [], screens: screens, visible: screens).filter { $0.kind == .floor } }
    var home: DesktopHome { DesktopHome(screen: screens[1], floor: floors[1], corner: .right) }
    let day = Rhythm(hour: 12, quietEnabled: false)

    func testMealCrossesOffsetDisplaysWalksToBowlThenNapsOnPillow() throws {
        var pet = PetEngine(position: Point(-330, 220))
        pet.fillBowl()
        let serving = try JSONDecoder().decode(PetCare.self, from: JSONEncoder().encode(pet.care))
        XCTAssertTrue(serving.foodInBowl)
        var visited = Set<HomeActivity>()
        let surfaces = floors, target = home
        for _ in 0..<1500 {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: screens, rhythm: day, home: target)
            visited.insert(pet.homeActivity)
            XCTAssertTrue(screens.contains { $0.contains(pet.position) })
            if pet.homeActivity == .eating {
                XCTAssertEqual(pet.position, Point(target.diningX, target.floor.y))
                XCTAssertFalse(pet.care.foodInBowl)
                XCTAssertEqual(pet.action, .feed)
                pet.fillBowl() // A second click during the same bite is not another meal.
                XCTAssertFalse(pet.care.foodInBowl)
            }
            if pet.homeActivity == .napping {
                XCTAssertEqual(pet.position, Point(target.pillowX, target.floor.y))
                XCTAssertEqual(pet.action, .sleep)
            }
        }
        XCTAssertTrue(visited.isSuperset(of: [.goingToBowl, .eating, .goingToBed, .napping, .exploring]))
        XCTAssertFalse(pet.care.isHungry)
    }

    func testOnlyActiveTimeCreatesHungerAndWaitingHasNoPenalty() {
        var pet = PetEngine(position: Point(220, 140))
        let target = home, surfaces = floors
        pet.perch(on: target.floor, x: 220)
        for rhythm in [Rhythm(hour: 23), Rhythm(hour: 12, idleSeconds: 301)] {
            for _ in 0..<1000 { pet.tick(dt: 1, surfaces: surfaces, screens: screens, rhythm: rhythm, home: target) }
        }
        XCTAssertEqual(pet.care.awakeSeconds, 0)
        for _ in 0..<1000 { pet.tick(dt: 1, surfaces: surfaces, screens: screens, rhythm: day, home: target, reduceMotion: true) }
        XCTAssertEqual(pet.homeActivity, .waiting)
        XCTAssertEqual(pet.care.awakeSeconds, PetCare.mealInterval)
        XCTAssertEqual(pet.position, Point(target.diningX, target.floor.y))
        pet.setBed(true); pet.tick(dt: 1, surfaces: surfaces, screens: screens, rhythm: day, home: target)
        XCTAssertTrue(pet.bed); XCTAssertEqual(pet.state, .sleep)
        pet.fillBowl(); pet.tick(dt: 0.1, surfaces: surfaces, screens: screens, rhythm: day, home: target)
        XCTAssertFalse(pet.bed); XCTAssertEqual(pet.homeActivity, .eating); XCTAssertEqual(pet.care.awakeSeconds, 0)
    }

    func testPendingMealSurvivesPickupAndUnavailableOrRelocatedHome() {
        var pet = PetEngine(position: Point(-75, 0))
        let surfaces = floors, original = home
        pet.fillBowl(); pet.hold(at: pet.position)
        pet.tick(dt: 0.1, surfaces: surfaces, screens: screens, rhythm: day, home: original)
        XCTAssertEqual(pet.state, .held)
        pet.release(); pet.tick(dt: 0.1, surfaces: surfaces, screens: screens, rhythm: day)
        XCTAssertTrue(pet.care.foodInBowl)
        for _ in 0..<30 {
            pet.tick(dt: 0.1, surfaces: surfaces, screens: screens, rhythm: day, home: original, reduceMotion: true)
            if pet.position.x == original.diningX { break }
        }
        XCTAssertEqual(pet.position.x, original.diningX); XCTAssertTrue(pet.care.foodInBowl)
        let moved = DesktopHome(screen: screens[0], floor: surfaces[0])
        for _ in 0..<2 { pet.tick(dt: 0.1, surfaces: surfaces, screens: screens, rhythm: day, home: moved, reduceMotion: true) }
        XCTAssertEqual(pet.support, moved.floor)
        XCTAssertEqual(pet.position.x, moved.diningX); XCTAssertEqual(pet.homeActivity, .eating)
    }

    func testCuriousPetAutonomouslyTugsTwiceThenMountsUnmovedLedge() {
        let floor = floors[1], target = home
        let ledge = Surface(id: "owned", windowID: 7, left: 0, right: 800, y: 340)
        let surfaces = [floor, ledge]
        var pet = PetEngine(position: Point(400, floor.y))
        pet.perch(on: floor, x: 400)
        for _ in 0..<2400 {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: screens, rhythm: day, home: target)
            if pet.state == .climb { break }
        }
        XCTAssertEqual(pet.state, .climb)
        var hanging: [Double] = []
        for step in 1...50 {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: screens, rhythm: day, home: target)
            if (17...37).contains(step) { hanging.append(pet.position.y) }
        }
        let peaks = (1..<hanging.count - 1).filter { hanging[$0] > hanging[$0 - 1] && hanging[$0] > hanging[$0 + 1] }
        XCTAssertEqual(peaks.count, 2)
        XCTAssertEqual(pet.support, ledge); XCTAssertEqual(pet.position.y, ledge.y)
    }

    func testMealDirectlyBelowWindowUsesItsEdgeAndLandsOnIntermediateSupport() {
        let target = home
        let upper = Surface(id: "upper", windowID: 11, left: 490, right: 770, y: 400)
        let lower = Surface(id: "lower", windowID: 12, left: 600, right: 800, y: 270)
        let surfaces = floors + [lower, upper]
        var pet = PetEngine(position: Point(target.diningX, upper.y))
        pet.perch(on: upper, x: target.diningX); pet.fillBowl()
        var crossedLower = false
        for _ in 0..<500 {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: screens, rhythm: day, home: target)
            crossedLower = crossedLower || pet.support?.id == lower.id
            if pet.homeActivity == .eating { break }
        }
        XCTAssertTrue(crossedLower)
        XCTAssertEqual(pet.homeActivity, .eating)
        XCTAssertEqual(pet.support, target.floor)
    }

    func testTugLeavesRoomForPetAndRespectsStillMode() {
        let floor = floors[1]
        let clipped = Surface(id: "clipped", windowID: 5, left: 0, right: 800, y: screens[1].maxY - 10)
        let safe = Surface(id: "safe", windowID: 6, left: 0, right: 800, y: floor.y + 150)
        var pet = PetEngine(position: Point(300, floor.y))
        pet.perch(on: floor, x: 300)
        XCTAssertNil(pet.windowToClimb(surfaces: [floor, clipped], screens: screens, nearbyOnly: false))
        for _ in 0..<200 {
            pet.tick(dt: 0.5, surfaces: [floor, safe], screens: screens, rhythm: day, reduceMotion: true)
            XCTAssertEqual(pet.position, Point(300, floor.y))
        }
        pet.climb(to: safe)
        pet.tick(dt: 0.01, surfaces: [floor, safe], screens: screens, rhythm: day, reduceMotion: true)
        XCTAssertEqual(pet.support, safe)
    }
}
