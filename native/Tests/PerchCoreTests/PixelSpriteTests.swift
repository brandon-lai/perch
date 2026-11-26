import XCTest
@testable import PerchCore

final class PixelSpriteTests: XCTestCase {
    private func solid(_ art: PixelArt, _ x: Int, _ y: Int) -> Bool { art[x, y] != "." && art[x, y] != "x" }

    func testEveryPoseFitsItsOutlineAndKeepsPawsOnItsSurface() {
        let grounded: Set<Action> = [.idle, .walk, .sit, .ride, .react, .pet, .feed, .play, .sniff, .stretch,
                                     .yawn, .shake, .look, .highFive]
        func fits(_ art: PixelArt, _ label: String) {
            for i in 0..<32 {
                XCTAssertFalse(solid(art, i, 0) || solid(art, i, 31) || solid(art, 0, i) || solid(art, 31, i),
                               "\(label) touches the edge, leaving no room for its outline")
            }
        }
        for pose in SpecialPose.allCases {
            let special = PixelSprites.special(pose)
            XCTAssertEqual(special.slots.count, 12)
            XCTAssertTrue(special.slots.allSatisfy(special.frames.indices.contains), "\(pose)")
            for art in special.frames { fits(art, "\(pose)") }
        }
        for action in Action.allCases {
            let animation = PixelSprites.animation(action)
            let label = "\(action)"
            XCTAssertEqual(animation.slots.count, 12, label)
            XCTAssertTrue(animation.slots.allSatisfy(animation.frames.indices.contains), label)
            for art in animation.frames {
                fits(art, label)
                if grounded.contains(action) { XCTAssertTrue((0..<32).contains { solid(art, $0, 30) }, "\(label) floats above its surface") }
                if action == .climb { XCTAssertTrue((0..<32).contains { solid(art, $0, PixelSprites.climbLedgeRow - 1) }, label) }
                if action == .peek { XCTAssertTrue((0..<32).contains { solid(art, $0, 1) }, label) }
            }
        }
    }

    func testTheWalkingTailIsLongAndRingedAndTheRunIsAGallop() {
        let walk = PixelSprites.animation(.walk).frames[0]
        let tail = (0..<32).flatMap { x in (0..<32).filter { walk[x, $0] == "T" }.map { (x, $0) } }
        XCTAssertGreaterThan(tail.count, 30, "plenty of rings")
        XCTAssertLessThan(tail.map(\.1).min() ?? 32, 9, "sweeps up well above its back")
        let run = PixelSprites.special(.run)
        XCTAssertEqual(Set(run.slots).count, 2)
        func feet(_ art: PixelArt) -> Int { (0..<32).filter { solid(art, $0, 30) }.count }
        XCTAssertGreaterThan(spread(run.frames[0]), spread(run.frames[1]) + 6, "stretches out, then gathers")
        XCTAssertGreaterThan(feet(run.frames[0]), 0)
    }

    private func spread(_ art: PixelArt) -> Int {
        let xs = (0..<32).filter { solid(art, $0, 30) }
        return (xs.max() ?? 0) - (xs.min() ?? 0)
    }

    func testRedPandaHangsByItsTeethAndDrapesWithItsBellyOnTheEdge() {
        let hang = PixelSprites.special(.hang)
        XCTAssertEqual(hang.frames[0][15, PixelSprites.hangGripRow], "m", "open mouth sits on the pointer's tip")
        let drape = PixelSprites.special(.drape).frames[0]
        let body: Set<Character> = ["c", "h", "s"]
        XCTAssertTrue((7...17).contains { body.contains(drape[$0, PixelSprites.drapeLedgeRow - 1]) }, "belly rests on the edge")
        XCTAssertFalse((7...17).contains { body.contains(drape[$0, PixelSprites.drapeLedgeRow]) }, "only legs hang below it")
        XCTAssertTrue((7...24).contains { solid(drape, $0, PixelSprites.drapeLedgeRow + 3) }, "legs dangle")
    }

    func testPackColorsDressThePandaAndItsFaceMaskKeepsASoftEdge() {
        let pack = PetPack.redPanda()
        let palette = PixelPalette(pack: pack)
        XCTAssertEqual(palette.colors["c"], RGB(hex: pack.coat))
        XCTAssertEqual(palette.colors["1"], RGB(hex: pack.earColor), "legs")
        XCTAssertEqual(palette.colors["u"], RGB(hex: pack.markingColor), "face mask")
        XCTAssertEqual(palette.colors["f"], RGB(hex: pack.markingColor), "ear rims")
        XCTAssertTrue(palette.softChars.contains("u")); XCTAssertFalse(palette.softChars.contains("c"))
        var art = PixelArt(width: 5, height: 3)
        art[1, 1] = "u"; art[3, 1] = "c"; art[4, 0] = "x"
        let rgba = palette.rgba(art)
        func pixel(_ x: Int, _ y: Int) -> RGB? {
            let i = (y * 5 + x) * 4
            return rgba[i + 3] == 0 ? nil : RGB(rgba[i], rgba[i + 1], rgba[i + 2])
        }
        XCTAssertEqual(pixel(0, 1), palette.softOutline, "the white mask keeps a soft edge")
        XCTAssertEqual(pixel(2, 1), palette.outline, "edges shared with fur stay dark")
        XCTAssertEqual(pixel(4, 0), palette.colors["x"], "whiskers draw over the outline")
        XCTAssertNil(pixel(0, 0), "corners stay transparent")
    }

    func testTheTreeFitsItsOutlineWithASolidBranchAndTrunk() {
        let tree = PixelTree.art()
        for x in 0..<tree.width { XCTAssertEqual(tree[x, 0], "."); XCTAssertEqual(tree[x, tree.height - 1], ".") }
        for y in 0..<tree.height { XCTAssertEqual(tree[0, y], "."); XCTAssertEqual(tree[tree.width - 1, y], ".") }
        for x in PixelTree.branchFrom...PixelTree.branchTo { XCTAssertNotEqual(tree[x, PixelTree.branchTop], ".", "branch at \(x)") }
        XCTAssertEqual(tree[PixelTree.branchFrom + 4, PixelTree.branchTop - 1], ".", "room to stand on the branch")
        XCTAssertNotEqual(tree[Int(PixelTree.trunkCenter), tree.height - 2], ".", "trunk reaches the floor")
    }
}
