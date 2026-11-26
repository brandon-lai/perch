import { test, expect } from "@playwright/test"

test("local photos, confirmed traits, and downloaded pack complete the native handoff", async ({
  page,
}) => {
  await page.goto("/make")
  await page
    .getByRole("button", { name: "Choose their traits", exact: true })
    .click()
  await expect(page.locator("main [role=alert]")).toContainText("3 to 10")
  const encodedPhoto = await page.evaluate(() => {
    const canvas = document.createElement("canvas")
    canvas.width = 64
    canvas.height = 64
    const context = canvas.getContext("2d")!
    context.fillStyle = "#c58b55"
    context.fillRect(0, 0, 64, 64)
    return canvas.toDataURL("image/png").split(",")[1]
  })
  const photo = Buffer.from(encodedPhoto, "base64")
  await page.getByLabel("Choose your pet’s photos").setInputFiles(
    [1, 2, 3].map((index) => ({
      name: `reference-${index}.png`,
      mimeType: "image/png",
      buffer: photo,
    }))
  )
  await expect(page.getByText("3 photos chosen")).toBeVisible()
  await page
    .getByRole("button", { name: "Choose their traits", exact: true })
    .click()
  await page
    .getByRole("button", { name: "Keep this little pet", exact: true })
    .click()
  await expect(page.locator("main [role=alert]")).toContainText("name")
  await expect(page.getByLabel("Their name")).toBeFocused()
  await expect(page.getByLabel("Their name")).toHaveAccessibleDescription(
    /name/
  )
  await page.getByLabel("Their name").fill("  Pippin  ")
  await page.getByLabel("Species", { exact: true }).click()
  await page.getByRole("option", { name: "Cat", exact: true }).click()
  await expect(page.getByLabel("Ear shape", { exact: true })).toContainText(
    "Pointed"
  )
  await page
    .getByRole("button", { name: "Keep this little pet", exact: true })
    .click()
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Pippin, meet Perch."
  )
  const downloaded = page.waitForEvent("download")
  await page
    .getByRole("button", { name: "Save Pippin’s pet pack", exact: true })
    .click()
  const download = await downloaded
  expect(download.suggestedFilename()).toBe("Pippin.perchpack")
  const stream = await download.createReadStream()
  const chunks = []
  for await (const chunk of stream!) chunks.push(chunk)
  const pack = JSON.parse(Buffer.concat(chunks).toString("utf8"))
  expect(pack.species).toBe("cat")
  expect(pack.ears).toBe("pointed")
  expect(pack.animations).toHaveLength(19)
  expect(pack.name).toBe("Pippin")
  expect(pack.schemaVersion).toBe(1)
  expect(pack.rigVersion).toBe("perch-1")
  expect(JSON.stringify(pack)).not.toContain("reference-")
  await page.getByRole("button", { name: "Remove local photos" }).click()
  await expect(
    page.getByRole("img", { name: "Reference photo 1" })
  ).toHaveCount(0)
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
  await playground.locator(".pet-hit ellipse").first().click()
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
  const body = (await pet.locator("ellipse").first().boundingBox())!
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
  await pet.locator("ellipse").first().click()
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
