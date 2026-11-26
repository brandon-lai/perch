import XCTest
@testable import PerchCore

final class PixelSpriteTests: XCTestCase {
    private func solid(_ art: PixelArt, _ x: Int, _ y: Int) -> Bool { art[x, y] != "." && art[x, y] != "x" }

    func testEveryPoseFitsItsOutlineAndKeepsPawsOnItsSurface() {
        let grounded: Set<Action> = [.idle, .walk, .sit, .ride, .react, .pet, .feed, .play, .sniff, .stretch,
                                     .yawn, .shake, .look, .highFive]
        for species in Species.allCases {
            for ears in Ears.allCases {
                for action in Action.allCases {
                    for atDish in [false, true] {
                        let animation = PixelSprites.animation(action, species: species, ears: ears, atDish: atDish)
                        let label = "\(species) \(ears) \(action)"
                        XCTAssertEqual(animation.slots.count, 12, label)
                        XCTAssertTrue(animation.slots.allSatisfy(animation.frames.indices.contains), label)
                        for art in animation.frames {
                            for i in 0..<32 {
                                XCTAssertFalse(solid(art, i, 0) || solid(art, i, 31) || solid(art, 0, i) || solid(art, 31, i),
                                               "\(label) touches the edge, leaving no room for its outline")
                            }
                            let row = (0..<32).contains { x in solid(art, x, 30) }
                            if grounded.contains(action) { XCTAssertTrue(row, "\(label) floats above its surface") }
                            if action == .climb {
                                XCTAssertTrue((0..<32).contains { solid(art, $0, PixelSprites.climbLedgeRow - 1) }, label)
                            }
                            if action == .peek { XCTAssertTrue((0..<32).contains { solid(art, $0, 1) }, label) }
                        }
                    }
                }
            }
        }
    }

    func testMarkingsRecolorOnlyTheirPixelsAndLightEdgesStaySoft() {
        let coat = RGB(hex: "#3C3B48"), white = RGB(hex: "#F4F0EA")
        var pack = PetPack(coat: "#3C3B48", markingColor: "#F4F0EA", marking: .socks)
        let socks = PixelPalette(pack: pack)
        XCTAssertEqual(socks.colors["1"], white); XCTAssertEqual(socks.colors["w"], coat)
        XCTAssertTrue(socks.softChars.contains("1")); XCTAssertFalse(socks.softChars.contains("c"))
        pack.marking = .none
        let plain = PixelPalette(pack: pack)
        XCTAssertEqual(plain.colors["1"], coat); XCTAssertEqual(plain.colors["u"], white)
        XCTAssertFalse(plain.softChars.contains("1"))

        var art = PixelArt(width: 5, height: 3)
        art[1, 1] = "1"; art[3, 1] = "c"; art[4, 0] = "x"
        let rgba = socks.rgba(art)
        func pixel(_ x: Int, _ y: Int) -> RGB? {
            let i = (y * 5 + x) * 4
            return rgba[i + 3] == 0 ? nil : RGB(rgba[i], rgba[i + 1], rgba[i + 2])
        }
        XCTAssertEqual(pixel(1, 1), white)
        XCTAssertEqual(pixel(0, 1), socks.softOutline, "a white paw keeps a soft edge")
        XCTAssertEqual(pixel(2, 1), socks.outline, "edges shared with dark fur stay dark")
        XCTAssertEqual(pixel(4, 0), socks.colors["x"], "whiskers draw over the outline")
        XCTAssertNil(pixel(0, 0), "corners stay transparent")
    }

    func testEatingNoseReachesTheHomeBowlAtEveryPetSize() {
        let floor = Surface(id: "floor", left: 0, right: 1200, y: 40, kind: .floor)
        for species in Species.allCases {
            let art = PixelSprites.animation(.feed, species: species, ears: .floppy, atDish: true).frames[0]
            let nose = (0..<32).last { x in (18...27).contains { solid(art, x, $0) } }!
            for scale in [2.0, 3.0, 4.0] {
                let home = DesktopHome(screen: Rect(0, 0, 1200, 800), floor: floor, scale: scale)
                let tip = home.diningX + (Double(nose) + 1 - 16) * scale
                XCTAssertGreaterThan(tip, home.origin.x + Double(PixelHome.bowlX + 2) * scale, "\(species) \(scale)")
                XCTAssertLessThan(tip, home.origin.x + Double(PixelHome.bowlX + 12) * scale, "\(species) \(scale)")
                XCTAssertTrue(home.onRug(home.pillowX) && home.onRug(home.diningX))
            }
        }
    }
}
