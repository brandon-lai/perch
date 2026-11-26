import { test, expect } from "@playwright/test"

test("naming and coloring a red panda, then downloading its pack, completes the native handoff", async ({
  page,
}) => {
  await page.goto("/make")
  await expect(page.getByLabel("Live red panda preview").getByRole("img", { name: /red panda/ })).toBeVisible()
  await page
    .getByRole("button", { name: "Keep this red panda", exact: true })
    .click()
  await expect(page.locator("main [role=alert]")).toContainText("name")
  await expect(page.getByLabel("Its name")).toBeFocused()
  await expect(page.getByLabel("Its name")).toHaveAccessibleDescription(/name/)
  await page.getByLabel("Its name").fill("  Pippin  ")
  await page.getByLabel("Coat").fill("#b9532a")
  await page.getByLabel("Size", { exact: true }).click()
  await page.getByRole("option", { name: "Small", exact: true }).click()
  await page
    .getByRole("button", { name: "Keep this red panda", exact: true })
    .click()
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Pippin, meet your desktop."
  )
  const downloaded = page.waitForEvent("download")
  await page
    .getByRole("button", { name: "Save Pippin’s pack", exact: true })
    .click()
  const download = await downloaded
  expect(download.suggestedFilename()).toBe("Pippin.perchpack")
  const stream = await download.createReadStream()
  const chunks = []
  for await (const chunk of stream!) chunks.push(chunk)
  const pack = JSON.parse(Buffer.concat(chunks).toString("utf8"))
  expect(pack.species).toBe("redPanda")
  expect(pack.ears).toBe("pointed")
  expect(pack.coat.toLowerCase()).toBe("#b9532a")
  expect(pack.size).toBe("small")
  expect(pack.animations).toHaveLength(19)
  expect(pack.name).toBe("Pippin")
  expect(pack.schemaVersion).toBe(1)
  expect(pack.rigVersion).toBe("perch-1")
  await page.getByRole("button", { name: "Change its details" }).click()
  await page.getByRole("button", { name: "Use red panda colors" }).click()
  await expect(page.getByLabel("Coat")).toHaveValue("#d9772e")
})

test("the perch is keyboard-movable, cancellable, and pausable", async ({
  page,
}) => {
  await page.goto("/")
  const playground = page.locator(".playground").first()
  const surface = playground.getByRole("button", {
    name: "Move the perch: drag, or use arrow keys",
  })
  await surface.focus()
  await surface.press("ArrowRight")
  await expect(playground.locator(".moving-perch")).toHaveAttribute(
    "style",
    /12px/
  )
  await expect(playground).toHaveAttribute("data-pose", "ride")
  await surface.press("Escape")
  await expect(playground.locator(".moving-perch")).toHaveAttribute(
    "style",
    /0px, 0px/
  )
  await playground.getByRole("button", { name: "Pause animation" }).click()
  await expect(
    playground.getByRole("button", { name: "Resume animation" })
  ).toHaveAttribute("aria-pressed", "true")
  await expect(surface).toBeDisabled()
  await playground.getByRole("button", { name: "Resume animation" }).click()
  await playground.getByRole("button", { name: "Nap", exact: true }).click()
  await expect(playground).toHaveAttribute("data-pose", "sleep")
  await playground.getByRole("button", { name: "Wake", exact: true }).click()
  await expect(playground).toHaveAttribute("data-pose", "idle")
})

test("a real pointer drag rides slowly and tumbles quickly without breaking pet clicks", async ({
  page,
}) => {
  await page.goto("/")
  const playground = page.locator(".playground").first()
  const surface = playground.locator(".perch-surface")
  const bounds = (await surface.boundingBox())!
  await page.mouse.move(bounds.x + 160, bounds.y + 10)
  await page.mouse.down()
  for (let step = 1; step <= 6; step++) {
    await page.waitForTimeout(50)
    await page.mouse.move(bounds.x + 160 + step * 4, bounds.y + 10)
  }
  await expect(playground).toHaveAttribute("data-pose", "ride")
  await page.mouse.up()
  await expect(playground).toHaveAttribute("data-pose", "idle")
  await page.mouse.move(bounds.x + 184, bounds.y + 10)
  await page.mouse.down()
  await page.mouse.move(bounds.x + 270, bounds.y + 10)
  await page.mouse.up()
  await expect(playground).toHaveAttribute("data-pose", "fall")
  await expect(playground).toHaveAttribute("data-pose", "idle", {
    timeout: 4000,
  })
  await playground
    .getByRole("button", { name: "Move the pet or perch" })
    .click()
  await page.getByRole("menuitem", { name: "Reset perch", exact: true }).click()
  const verticalBounds = (await surface.boundingBox())!
  await page.mouse.move(verticalBounds.x + 120, verticalBounds.y + 10)
  await page.mouse.down()
  await page.mouse.move(verticalBounds.x + 120, verticalBounds.y + 85)
  await page.mouse.up()
  await expect(playground).toHaveAttribute("data-pose", "fall")
  await playground.getByRole("button", { name: "Pause animation" }).click()
  await playground.getByRole("button", { name: "Resume animation" }).click()
  await expect(playground).toHaveAttribute("data-pose", "idle")
  await playground.locator(".pet-hit path").first().click()
  await expect(playground).toHaveAttribute("data-pose", "pet")
})

test("single-pointer menu actions move both objects and restore focus", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 900 })
  await page.goto("/")
  const playground = page.locator(".playground").first()
  const trigger = playground.getByRole("button", {
    name: "Move the pet or perch",
  })
  const choose = async (name: string) => {
    await trigger.click()
    await page.getByRole("menuitem", { name, exact: true }).click()
  }
  await choose("Move perch right")
  await expect(playground.locator(".moving-perch")).toHaveAttribute(
    "style",
    /12px, 0px/
  )
  await choose("Lift pet")
  await expect(playground).toHaveAttribute("data-pose", "held")
  await expect(playground.locator(".pet-hit")).toHaveAttribute(
    "style",
    /--pet-y: -24px/
  )
  await choose("Drop pet")
  await expect(playground).toHaveAttribute("data-grounded", "true")
  await choose("Reset perch")
  await expect(playground.locator(".moving-perch")).toHaveAttribute(
    "style",
    /0px, 0px/
  )
  await trigger.focus()
  await trigger.press("Enter")
  await expect(page.getByRole("menu")).toBeVisible()
  await page.keyboard.press("Escape")
  await expect(page.getByRole("menu")).not.toBeVisible()
  await expect(trigger).toBeFocused()
})

test("picking up the pet leaves its perch behind and lands on a stationary floor", async ({
  page,
}) => {
  await page.goto("/")
  const playground = page.locator(".playground").first()
  const pet = playground.locator(".pet-hit")
  const bounds = (await pet.boundingBox())!
  const body = (await pet.locator("path").first().boundingBox())!
  const originalSurface = (await playground
    .locator(".perch-surface")
    .boundingBox())!
  await page.mouse.move(body.x + body.width / 2, body.y + body.height / 2)
  await page.mouse.down()
  await page.mouse.move(
    body.x + body.width / 2 + 26,
    body.y + body.height / 2 - 34,
    { steps: 5 }
  )
  await expect(playground).toHaveAttribute("data-pose", "held")
  expect(await pet.boundingBox()).not.toEqual(bounds)
  expect(await playground.locator(".perch-surface").boundingBox()).toEqual(
    originalSurface
  )
  await page.mouse.up()
  await expect(playground).toHaveAttribute("data-grounded", "true")
  const landed = (await pet.boundingBox())!
  const floor = (await playground.locator(".ground-line").boundingBox())!
  expect(Math.abs(landed.y + landed.height - floor.y)).toBeLessThan(1)
  await playground
    .getByRole("button", { name: "Move the pet or perch" })
    .click()
  await page.getByRole("menuitem", { name: "Raise perch", exact: true }).click()
  expect(await pet.boundingBox()).toEqual(landed)
  await pet.locator("path").first().click()
  await expect(playground).toHaveAttribute("data-pose", "pet")
  expect(await pet.boundingBox()).toEqual(landed)
  await page.goto("/make")
  const compact = page.locator(".playground")
  await compact.getByRole("button", { name: "Move the pet or perch" }).click()
  await page.getByRole("menuitem", { name: "Drop pet", exact: true }).click()
  await expect(compact).toHaveAttribute("data-grounded", "true")
  const compactPet = (await compact.locator(".pet-hit").boundingBox())!
  const compactFloor = (await compact.locator(".ground-line").boundingBox())!
  expect(
    Math.abs(compactPet.y + compactPet.height - compactFloor.y)
  ).toBeLessThan(1)
})

test("the installation dialog closes with Escape and restores focus", async ({
  page,
}) => {
  await page.goto("/download")
  const trigger = page.getByRole("button", { name: "Read installation notes" })
  await trigger.click()
  await expect(page.getByRole("dialog")).toBeVisible()
  await page.keyboard.press("Escape")
  await expect(page.getByRole("dialog")).not.toBeVisible()
  await expect(trigger).toBeFocused()
})

for (const width of [390, 320]) {
  test(`composed movement stays visible at ${width}px, including a large red panda and resize`, async ({
    page,
  }) => {
    await page.setViewportSize({ width, height: 900 })
    await page.goto("/")
    const playground = page.locator(".playground").first()
    async function choose(name: string, scene = playground) {
      await scene.getByRole("button", { name: "Move the pet or perch" }).click()
      await page.getByRole("menuitem", { name, exact: true }).click()
    }
    async function fits(scene = playground) {
      const result = await scene.evaluate((element) => {
        const space = element
          .querySelector(".play-space")!
          .getBoundingClientRect()
        const shape = element
          .querySelector(".pet-rig svg > g")!
          .getBoundingClientRect()
        const surface = element
          .querySelector(".perch-surface")!
          .getBoundingClientRect()
        return [shape, surface].map(
          (rect) =>
            rect.left >= space.left - 0.5 &&
            rect.right <= space.right + 0.5 &&
            rect.top >= space.top - 0.5 &&
            rect.bottom <= space.bottom + 0.5
        )
      })
      expect(result).toEqual([true, true])
    }
    for (const name of [
      "Move perch right",
      "Move pet right",
      "Move perch left",
      "Move pet left",
    ]) {
      for (let step = 0; step < 9; step++) await choose(name)
      await fits()
    }
    await page.goto("/make")
    await page.getByLabel("Size", { exact: true }).click()
    await page.getByRole("option", { name: "Large", exact: true }).click()
    const compact = page.locator(".playground")
    for (const name of ["Lift pet", "Raise perch", "Lower perch"]) {
      for (let step = 0; step < 9; step++) await choose(name, compact)
      await fits(compact)
    }
    await choose("Drop pet", compact)
    await expect(compact).toHaveAttribute("data-grounded", "true")
    await fits(compact)
    await page.setViewportSize({
      width: width === 390 ? 320 : 390,
      height: 900,
    })
    await expect(compact.locator(".moving-perch")).toHaveAttribute(
      "style",
      /0px, 0px/
    )
    await fits(compact)
  })
}

for (const width of [1440, 1024, 768, 390, 320]) {
  test(`home and builder fit a real ${width}px viewport`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    for (const route of ["/", "/make"]) {
      await page.goto(route)
      const spill = await page.locator("main").evaluate((main) =>
        [...main.querySelectorAll("*")]
          .filter((node) => {
            const element = node as HTMLElement
            const rect = element.getBoundingClientRect()
            return (
              rect.width > 0 &&
              rect.right > innerWidth + 1 &&
              getComputedStyle(element).position !== "absolute"
            )
          })
          .map((element) => element.className)
          .slice(0, 5)
      )
      expect(spill).toEqual([])
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth
        )
      ).toBe(true)
    }
  })
}
