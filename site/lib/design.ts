/** sRGB values of the web palette for images (Satori can't read CSS custom properties). See app/globals.css. */
export const IMAGE_TOKENS = {
  paper: "#fdf6ef",
  card: "#fffcfa",
  ink: "#1f1914",
  muted: "#756a5f",
  primary: "#b25201",
  sky: "#fff3ed",
  tint: "#ffe8dc",
  floor: "#ffd6c0",
  rule: "#ece0d4",
  dotClose: "#e3626e",
  dotMin: "#f3a958",
  dotZoom: "#6cbf64",
  displayFace: "PerchDisplay",
}

/** Perch's pixel paw (11 × 9 art pixels), as rectangles for images. */
export const PAW_RUNS: [number, number, number][] = [
  [3, 0, 2], [6, 0, 2], [3, 1, 2], [6, 1, 2], [1, 2, 2], [8, 2, 2], [1, 3, 2], [8, 3, 2],
  [4, 4, 3], [3, 5, 5], [2, 6, 7], [2, 7, 7], [3, 8, 2], [6, 8, 2],
]
