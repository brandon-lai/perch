import XCTest
@testable import PerchCore

final class TreeTests: XCTestCase {
    let screens = [Rect(-640, 0, 640, 600), Rect(0, 140, 800, 600)]
    var floors: [Surface] { Surfaces.build(windows: [], screens: screens, visible: screens).filter { $0.kind == .floor } }
    let day = Rhythm(hour: 12, quietEnabled: false)

    private func panda(at point: Point, on surface: Surface) -> PetEngine {
        var pet = PetEngine(position: point)
        pet.agile = true; pet.bodyHalfWidth = 24; pet.muzzleReach = 21
        pet.perch(on: surface, x: point.x)
        return pet
    }

    func testTheTreeStandsWhereItIsPutAndItsBranchIsALedgeInsideIt() {
        let floor = floors[1]
        let left = TreeHome(floor: floor, position: 0, scale: 1.5), right = TreeHome(floor: floor, position: 1, scale: 1.5)
        XCTAssertEqual(left.origin, Point(floor.left, floor.y))
        XCTAssertEqual(right.bounds.maxX, floor.right, accuracy: 0.001)
        XCTAssertEqual(TreeHome(floor: floor, position: 7, scale: 1.5).origin, right.origin, "clamped to the floor")
        let middle = TreeHome(floor: floor, position: TreeHome.position(centeredAt: 400, floor: floor, scale: 1.5), scale: 1.5)
        XCTAssertEqual(middle.bounds.midX, 400, accuracy: 0.001)
        let branch = middle.branch
        XCTAssertEqual(branch.kind, .branch)
        XCTAssertTrue(middle.bounds.contains(Point(branch.left, branch.y)) && middle.bounds.contains(Point(branch.right, branch.y)))
        XCTAssertTrue(branch.supports(middle.restX))
        XCTAssertGreaterThan(branch.y, floor.y + 30, "high enough to nap above the floor")
    }

    func testBedtimeSendsItAcrossDisplaysUpTheTrunkToNapDrapedOnTheBranchAndItComesDownHeadFirst() {
        let tree = TreeHome(floor: floors[1], position: 0.7, scale: 1.5)
        var pet = panda(at: Point(-330, 0), on: floors[0])
        let night = Rhythm(hour: 23, quietStart: 22, quietEnd: 7)
        var crawledUp = false, crossed = false
        for _ in 0..<(30 * 60) where pet.state != .sleep {
            pet.tick(dt: 1.0 / 30, surfaces: floors, screens: screens, rhythm: night, tree: tree)
            if pet.support?.id == tree.floor.id { crossed = true }
            if pet.trickPose == .crawl && pet.position.x == tree.trunkX { crawledUp = true }
            XCTAssertTrue(screens.contains { $0.contains(pet.position) })
        }
        XCTAssertTrue(crossed, "walks over to the tree's display")
        XCTAssertTrue(crawledUp, "crawls up the trunk")
        XCTAssertEqual(pet.support?.id, tree.branch.id)
        XCTAssertEqual(pet.trickPose, .drape, "sleeps draped over the branch")
        XCTAssertEqual(pet.treeActivity, .inTree)
        for _ in 0..<60 { pet.tick(dt: 1.0 / 30, surfaces: floors, screens: screens, rhythm: night, tree: tree) }
        XCTAssertEqual(pet.support?.id, tree.branch.id, "stays asleep up there all night")

        // Morning: it stretches, walks to the trunk and comes down head first.
        var descended = false
        for _ in 0..<(30 * 30) where pet.support?.kind != .floor {
            pet.tick(dt: 1.0 / 30, surfaces: floors, screens: screens, rhythm: day, tree: tree)
            if pet.trickPose == .descend { descended = true }
        }
        XCTAssertTrue(descended)
        XCTAssertEqual(pet.support?.id, tree.floor.id); XCTAssertEqual(pet.treeActivity, .exploring)
    }

    func testAVisitIsAShortRestThenBackToExploringAndTheBranchMovesWithTheTree() {
        var tree = TreeHome(floor: floors[1], position: 0.2, scale: 1.5)
        var pet = panda(at: Point(700, floors[1].y), on: floors[1])
        pet.goToTree()
        for _ in 0..<(30 * 30) where pet.support?.id != tree.branch.id {
            pet.tick(dt: 1.0 / 30, surfaces: floors, screens: screens, rhythm: day, tree: tree)
        }
        XCTAssertEqual(pet.support?.id, tree.branch.id)
        // Dragged along with the panda on it: the panda rides the branch.
        let before = pet.position.x, start = tree.origin.x
        for step in 1...20 {
            tree = TreeHome(floor: floors[1], position: 0.2 + 0.005 * Double(step), scale: 1.5)
            pet.tick(dt: 1.0 / 30, surfaces: floors, screens: screens, rhythm: day, tree: tree)
        }
        XCTAssertEqual(pet.support?.id, tree.branch.id, "a steady drag doesn't throw it off")
        XCTAssertEqual(pet.position.x - before, tree.origin.x - start, accuracy: 30, "rides the branch along (while pottering on it)")
        XCTAssertGreaterThan(pet.position.x - before, 20)
        var left = false
        for _ in 0..<(30 * 60) where !left {
            pet.tick(dt: 1.0 / 30, surfaces: floors, screens: screens, rhythm: day, tree: tree)
            left = pet.treeActivity == .exploring && pet.support?.kind == .floor
        }
        XCTAssertTrue(left, "climbs down when the visit is over")
    }

    func testPettingItOnTheWayToItsTreeGetsAReactionFirst() {
        let tree = TreeHome(floor: floors[1], position: 0.2, scale: 1.5)
        var pet = panda(at: Point(700, floors[1].y), on: floors[1])
        pet.goToTree()
        for _ in 0..<10 { pet.tick(dt: 1.0 / 30, surfaces: floors, screens: screens, rhythm: day, tree: tree) }
        pet.react(.pet)
        for _ in 0..<30 {
            pet.tick(dt: 1.0 / 30, surfaces: floors, screens: screens, rhythm: day, tree: tree)
            XCTAssertEqual(pet.action, .pet, "enjoys the attention before carrying on")
        }
    }

    func testWithoutATreeItSleepsWhereItIs() {
        var pet = panda(at: Point(300, floors[1].y), on: floors[1])
        pet.tick(dt: 1.0 / 30, surfaces: floors, screens: screens, rhythm: Rhythm(hour: 23, quietStart: 22, quietEnd: 7))
        XCTAssertEqual(pet.treeActivity, .exploring)
        XCTAssertEqual(pet.state, .sleep)
    }

    func testCuriousPetAutonomouslyTugsTwiceThenMountsUnmovedLedge() {
        let floor = floors[1]
        let ledge = Surface(id: "owned", windowID: 7, left: 0, right: 800, y: 340)
        let surfaces = [floor, ledge]
        var pet = PetEngine(position: Point(400, floor.y))
        pet.perch(on: floor, x: 400)
        for _ in 0..<2400 {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: screens, rhythm: day)
            if pet.state == .climb { break }
        }
        XCTAssertEqual(pet.state, .climb)
        var hanging: [Double] = []
        for step in 1...50 {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: screens, rhythm: day)
            if (17...37).contains(step) { hanging.append(pet.position.y) }
        }
        let peaks = (1..<hanging.count - 1).filter { hanging[$0] > hanging[$0 - 1] && hanging[$0] > hanging[$0 + 1] }
        XCTAssertEqual(peaks.count, 2)
        XCTAssertEqual(pet.support, ledge); XCTAssertEqual(pet.position.y, ledge.y)
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
