---
name: design-system
description: Machina design system quick reference. Use when discussing design tokens, surfaces, card backgrounds, depth, elevation, typography tokens, color tokens, DaisyUI theming, or applying visual styling to UI components.
---

# Machina Design System — Quick Reference

The shared visual language for Machina apps. Each app picks its
own brand gem and theme name but inherits the surface, shape, typography, and
spacing rules below.

## Hierarchy of Styling (strict order)

1. **DaisyUI semantic classes** — `btn-primary`, `bg-base-200`, `card`, `badge-success`
2. **Tailwind utilities** — `flex`, `gap-4`, `text-sm`, `p-6`
3. **Design system classes from `main.css`** — `.f-display`, `.f-mono`, `.nav-item`
4. **Add to `main.css`** — new patterns go here, then use the class
5. **Never** — inline styles, per-page style blocks, `!important` in HTML, hardcoded hex

## Surfaces — Core Rules

### Dark Mode (Pantheon Blue-Gray)
Depth = surface lightness. **NO shadows.**
- `base-100` (#0F131A) — Page background (deepest void)
- `base-200` (#171B21) — Cards, containers
- `base-300` (#1E2228) — Elevated elements, borders
- `neutral`  (#2C333B) — Highest elevation (popovers, nav)

### Light Mode (Warm Marble)
Depth = shadow. White cards on warm marble.
- `base-100` (#F5F0E8) — Page background (warm marble, NOT #FFF)
- `base-200` (#FFFFFF) — Cards, elevated surfaces (WHITE)
- `base-300` (#EFEBE0) — Warm dividers, borders
- `neutral`  (#E5DFD3) — Muted background areas

**KEY RULE:** Cards are `bg-base-200` (full opacity). In light mode this is
white on warm marble; in dark mode it's a slightly lighter surface. Never use
`bg-base-200/40` — the opacity destroys the depth hierarchy.

## Shapes (Wall / Arch / Tessera)

- **Wall**    (8px / `rounded-box`)  — Containers, cards
- **Arch**    (pill / `rounded-full`) — Interactive: buttons, inputs, badges
- **Tessera** (4px / `rounded`)       — Atomic elements

## Typography

- **Display:** Cormorant Garamond (`.f-display`) — headings, headlines
- **Body:**    DM Sans                            — paragraphs, UI text
- **Mono:**    JetBrains Mono (`.f-mono`)         — code, data, timestamps
- **Stats:**   JetBrains Mono 700, 28px min, lining tabular figures

## App brand

Each Machina app declares its own gem (accent color) and `<app>-dark` /
`<app>-light` DaisyUI theme names. Fill in the brand block in this app's
`main.css` and update this skill to reflect the gem chosen for APPNAME.

## Seven Principles

Firmitas (reliable), Utilitas (purposeful), Venustas (proportioned beauty),
Symmetria (mathematical 4px grid spacing), Harmonia (family coherence), Techne
(obsessive precision), Telos (serves the user's goal).
