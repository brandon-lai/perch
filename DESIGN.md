---
version: beta
name: Perch
description: A little red panda, in the same space as your windows.
colors:
  paper: "oklch(0.977 0.012 67.7)"     # cream-50, page
  card: "oklch(0.993 0.004 56.4)"      # cream-0, cards and wells' frames
  well: "oklch(0.951 0.016 64.7)"      # cream-100, toolbars and notices
  ink: "oklch(0.219 0.013 61.8)"       # cocoa-950, text
  muted: "oklch(0.531 0.022 67.3)"     # cream-600, secondary text
  primary: "oklch(0.55 0.145 49.8)"    # rust-600, the one filled action
  primary-hover: "oklch(0.479 0.122 49.6)"
  link: "oklch(0.479 0.122 49.6)"      # rust-700
  sky: "oklch(0.972 0.015 48.6)"       # rust-50, behind the pixel scenes
  tint: "oklch(0.946 0.03 49.5)"       # rust-100, badges and the closing card
typography:
  display:
    fontFamily: Bricolage Grotesque
    fontSize: clamp(44px, 6vw, 76px)
    fontWeight: 700
    lineHeight: 1.02
    letterSpacing: -0.035em
  heading:
    fontFamily: Bricolage Grotesque
    fontSize: clamp(32px, 3.6vw, 44px)
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: -0.025em
  body:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: 600
    lineHeight: 1.5
rounded:
  control: 9999px
  small: 10px
  well: 24px
  card: 32px
spacing:
  xs: 4px
  sm: 8px
  compact: 12px
  md: 16px
  gutter: 24px
  lg: 40px
  xl: 64px
  section: 96px
components:
  button:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.card}"
    rounded: "{rounded.control}"
    height: 44px
---

# Perch

## Overview

Scene: a pet owner at a bright workday desk wants familiar company without
another demand on their attention. The native companion is **Experience**;
settings and the help page are **Operate**; the download page is **Persuade**.

Mechanism: one consistent little animal treats the edges of actual windows as
places to stand, ride, and fall. The category's rut is a chatbot mascot beside
a feature-card grid. We deliberately do neither.

Audience world: sunny window sills, family photo albums, ceramic water bowls,
felt animal toys, a familiar collar, handwritten pet-sitter notes. These span
architecture, paper, ceramic, textile, and leather. **The window sill** carries
the mechanism. The site and the Mac app share one red panda: 32 px pixel art
from the same sprite grids (see below).

Signature: moving a perch moves the pet; moving it quickly makes the pet
tumble. The site demonstrates this actual interaction, not a fake Mac window.

Mirror test: a neighbouring assistant PRD would choose a chat layout. Perch
instead makes a small shared rig and empty physical space the central object.

## Colors

A warm window sill, taken from the red panda itself: cream paper (its face mask),
cocoa ink (its legs and outline) and one rust accent (its coat). Primitives are
named by hue (`--cream-*`, `--rust-*`, `--cocoa-950`) and only semantic tokens
(`--background`, `--primary`, `--link`, `--badge`…) are used by components. Rust
fills exactly one action per view; everything else is cream. The pixel art keeps
its own palette as art, not UI color.

Measured in the rendered site (every text element on every page, against the
background actually behind it): 63 pairs, all passing. Body ink is 15–17:1, muted
text 4.56:1 at its lowest (on the cream notice), cream on the rust button 5.03:1,
rust links 6.4:1, and the rust focus ring at least 4.4:1 against cream surfaces.

## Typography

Bricolage Grotesque's irregular, friendly forms suit an animal without
infantilizing the owner. Manrope is the quieter, legible workday voice, in
regular, semibold (controls and labels) and bold. Native settings use the macOS
system face; the web wordmark carries the display face beside a pixel paw.
Headings wrap in balance, prose in pretty.

## Layout

Cap web content at 1200px. The home page is a statement beside the live pet
(its perch drawn as the top of a little window, since windows are its branches),
then a day in its life in four pixel moments, a second live scene, and a tinted
closing card with its tree. Documents are a single 760px column. On phones, the
pet and the action stay; secondary nav collapses to the Download button.

## Elevation & Depth

Shadows for elevation, borders only for structure (rules, separators). Cards take
a hairline ring plus a soft lift (`--shadow-border`); the live scenes and the
download card float a little higher (`--shadow-float`). Every shadow sits over a
`1px` transparent border so forced-colors mode still draws an edge.

## Shapes

Pill controls, 24px wells inside 32px cards with 8px between them (concentric:
outer radius = inner radius + padding). The pet and its tree, bamboo and z's are
the Mac app's own 32 px pixel grids, rendered as crisp SVG (one path per colour)
and placed the way the app places them: belly on a window's top edge, paws on a
side, teeth on the bamboo's end, asleep on the branch.

## Components

shadcn on Base UI: Button, Badge, Card surfaces, Alert, Kbd, Dialog and Dropdown
Menu, themed by the tokens above. Base element styles live in `@layer base` so
shadcn's utilities always win.

Motion (better-ui): buttons press to `0.96` over 150ms ease-out, never when
disabled and only without reduced motion; hover feedback is 150ms on colour.
The hero's badge, title, description, actions and scene rise in turn, 100ms
apart (opacity, 12px and 4px blur over 300ms); menus and the dialog enter in
300ms and leave in 150ms. Under reduced motion all of these fade only, and the
pet holds still. Icons are Lucide with non-scaling strokes: 1.5px beside
regular text, 2px on semibold controls.

## Do's and Don'ts

Do keep the pet the product. Do keep it opinionated: one red panda, one look,
nothing to configure but its name.
Do say local template, not AI likeness. Do keep memorial copy optional and
gentle. Don't invent recognition rates, pricing, or testimonials. Don't read
window titles, keystrokes, screenshots, or private content.

The drawn animal is the actual procedural product rig, not illustration
standing in for an available product. Known lint bookkeeping: Hallmark gate
20 is not a product requirement; Base UI transient animation attributes are
not script-dependent hidden-at-rest content (gate 62).

Social images use `site/lib/design.ts` tokens because Satori does not resolve
CSS custom properties; their sRGB values correspond to the web palette.

Motion scan: hover color/border changes intentionally snap; frequent controls
have no color animation, following the transform/opacity-only floor. The
pet's shake is an animal landing response, not an error-message shake recipe.
Off-screen and calm pets are still. Button opacity uses the press duration.

Render correction: native HTML buttons vertically center their content, so
the ledge initially painted below its coordinate and the pet seemed to float.
An explicit top-aligned flex layout makes the paws meet the painted ledge.
The input border was darkened after measured contrast fell below 3:1.

The social card uses an OFL-licensed static Bricolage 700 font instance
(48 optical size, 100 width), since Satori cannot read the variable font.
Its paws also meet its ledge rather than floating above it.

Final review correction: a Base UI movement menu provides click-only
alternatives to both drags. Pet and surface coordinates are independent;
dropped pets land on a fixed floor. The browser and social card now use the
native rig's actual geometry rather than a similar but different silhouette.
SVG painted regions receive pointer events, so transparent pet bounds do not
cover the perch. Press styling no longer cancels the live drag transform.

The final reviewer reproduced combined pet/perch movement clipping on phones.
Both pointer and menu moves now share constraints measured from the actual
play-space, pet silhouette and perch hit region, rather than separate arbitrary
offset caps. Resize/rig-shape changes recenter the sample without waking a nap.
Compact phone scenes retain enough height for the largest pointed-ear rig.
The reviewer verdict was FIX; the finding was then corrected and reproduced
successfully at both narrow widths. No additional review round is claimed.
