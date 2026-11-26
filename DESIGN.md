---
version: alpha
name: Perch
description: A little pet, in the same space as your windows.
colors:
  primary: "oklch(0.48 0.19 264)"
  paper: "oklch(0.975 0.009 254)"
  ink: "oklch(0.25 0.024 256)"
  muted: "oklch(0.48 0.026 256)"
  surface: "oklch(0.93 0.018 254)"
  border: "oklch(0.65 0.024 254)"
  pet-coat: "oklch(0.72 0.105 64)"
  pet-ear: "oklch(0.46 0.075 57)"
  pet-marking: "oklch(0.95 0.017 80)"
  error: "oklch(0.46 0.17 24)"
typography:
  display:
    fontFamily: Bricolage Grotesque
    fontSize: 80px
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: -0.035em
  heading:
    fontFamily: Bricolage Grotesque
    fontSize: 40px
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: -0.025em
  body:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: 700
    lineHeight: 1.5
rounded:
  sm: 8px
  md: 12px
  lg: 24px
  full: 9999px
spacing:
  tiny: 2px
  xs: 4px
  sm: 8px
  compact: 12px
  md: 16px
  gutter: 24px
  lg: 40px
  xl: 64px
  section: 96px
  wide: 144px
components:
  button:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.paper}"
    rounded: "{rounded.md}"
    height: 48px
  input:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    height: 48px
---

# Perch

## Overview

Scene: a pet owner at a bright workday desk wants familiar company without
another demand on their attention. The native companion is **Experience**;
settings and the pet builder are **Operate**; the download page is **Persuade**.

Mechanism: one consistent little animal treats the edges of actual windows as
places to stand, ride, and fall. The category's rut is a chatbot mascot beside
a feature-card grid. We deliberately do neither.

Audience world: sunny window sills, family photo albums, ceramic water bowls,
felt animal toys, a familiar collar, handwritten pet-sitter notes. These span
architecture, paper, ceramic, textile, and leather. **The window sill** carries
the mechanism. Soft flat silhouettes have stable, recognizable markings on the
site; the Mac app's pet is 32 px pixel art with the same traits (see below).

Signature: moving a perch moves the pet; moving it quickly makes the pet
tumble. The site demonstrates this actual interaction, not a fake Mac window.

Mirror test: a neighbouring assistant PRD would choose a chat layout. Perch
instead makes a small shared rig and empty physical space the central object.

## Colors

Restrained blue-tinted paper with a deep cornflower primary under 5% of the
viewport. The warm coat belongs to the pet, not to brand decoration. No
gradients, halos, or pure-white panels. Custom coat values are **user data**,
not UI colors; the rig receives them through color variables.

## Typography

Bricolage Grotesque's irregular, friendly forms suit an animal without
infantilizing the owner. Manrope is the quieter, legible workday voice.
Native settings use the macOS system face to preserve familiar platform
controls; the web wordmark carries the display face.

The web display scales fluidly from 48px to its recorded 80px maximum.
Headings wrap in balance, prose in pretty; no tracked caps or split-color
headlines. Use regular and bold only.

## Layout

Cap web content at 1280px. A left-aligned statement and a roomy interactive
perch replace device chrome. On phones, keep the pet and the action, drop
secondary instructions. Builders separate the live pet from labelled inputs,
not nested cards. Native settings use a familiar sidebar-free form.

## Elevation & Depth

Only floating ledges and the native pet use depth. Two blue-tinted layers:
0 16px 40px at 10% ink; 0 3px 8px at 8% ink. Forms use rules and pale wells.
No decorative glass, glow, hard offset shadows, or card grids.

## Shapes

12px controls, 24px major wells. The pet is a shared rig, not independently
generated frames. Ears, tail, coat and chest marking remain the same between
animations. On the site it is drawn flat; in the Mac app it is hand-placed
32 px pixel art with chibi proportions, a dark coat-toned outline (softened
next to white markings), hue-shifted coat ramps and the cornflower collar as
the one brand accent. Its desktop rug, cushion and bowl share that pixel grid.

## Components

Web behavior uses shadcn on Base UI. Controls have 48px targets, immediate
focus outlines, active translation, explicit loading/error/selected states.
Native behavior uses AppKit, SwiftUI and SpriteKit.

Motion: press 120ms; overlay entry 200ms, exit 140ms, with
cubic-bezier(0.23, 1, 0.32, 1). Transform and opacity only. Drag streams
coordinates, not transitions. Pet motion is the single authored moment.
Pause is always available, and reduced motion shows a still animal.

## Do's and Don'ts

Do keep the pet the product. Do show editable traits before creating a pack.
Do say local template, not AI likeness. Do keep memorial copy optional and
gentle. Don't invent recognition rates, pricing, or testimonials. Don't read
window titles, keystrokes, screenshots, or private content.

The drawn animal is the actual procedural product rig, not illustration
standing in for an available product. Known lint bookkeeping: Hallmark gate
20 is not a product requirement; Base UI transient animation attributes are
not script-dependent hidden-at-rest content (gate 62).

The local photo count is not a server success state (lint warning 70): files
must pass count/type/size checks and actually decode before this count appears.
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
