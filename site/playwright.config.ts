import { defineConfig } from "@playwright/test"
export default defineConfig({
  testDir: "./tests/browser",
  fullyParallel: false,
  use: {
    baseURL: process.env.PERCH_BASE_URL || "http://127.0.0.1:3107",
    channel: "chrome",
    headless: true,
    reducedMotion: "reduce",
  },
  reporter: "list",
  outputDir: "/tmp/perch-playwright-results",
})
