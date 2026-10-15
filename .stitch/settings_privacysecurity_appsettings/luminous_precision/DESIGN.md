---
name: Luminous Precision
colors:
  surface: '#101127'
  surface-dim: '#101127'
  surface-bright: '#36374f'
  surface-container-lowest: '#0b0c22'
  surface-container-low: '#181930'
  surface-container: '#1d1e34'
  surface-container-high: '#27283f'
  surface-container-highest: '#32334a'
  on-surface: '#e1e0ff'
  on-surface-variant: '#e0c0af'
  inverse-surface: '#e1e0ff'
  inverse-on-surface: '#2d2e46'
  outline: '#a78b7c'
  outline-variant: '#584235'
  surface-tint: '#ffb68b'
  primary: '#ffb68b'
  on-primary: '#522300'
  primary-container: '#ff7a00'
  on-primary-container: '#5c2800'
  inverse-primary: '#994700'
  secondary: '#deb7ff'
  on-secondary: '#4a007f'
  secondary-container: '#670fac'
  on-secondary-container: '#d2a0ff'
  tertiary: '#ffb2ba'
  on-tertiary: '#670020'
  tertiary-container: '#ff7288'
  on-tertiary-container: '#730025'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbc8'
  primary-fixed-dim: '#ffb68b'
  on-primary-fixed: '#321200'
  on-primary-fixed-variant: '#753400'
  secondary-fixed: '#f0dbff'
  secondary-fixed-dim: '#deb7ff'
  on-secondary-fixed: '#2c0050'
  on-secondary-fixed-variant: '#670fac'
  tertiary-fixed: '#ffd9dc'
  tertiary-fixed-dim: '#ffb2ba'
  on-tertiary-fixed: '#400011'
  on-tertiary-fixed-variant: '#910030'
  background: '#101127'
  on-background: '#e1e0ff'
  surface-variant: '#32334a'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 56px
    fontWeight: '800'
    lineHeight: 64px
    letterSpacing: -0.03em
  display-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 38px
    fontWeight: '800'
    lineHeight: 44px
    letterSpacing: -0.025em
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.005em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
    letterSpacing: 0em
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: 0em
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.25rem
  gutter-desktop: 1.75rem
  margin: 1rem
  margin-tablet: 1.5rem
  margin-desktop: 2.5rem
  space-2xs: 0.25rem
  space-xs: 0.375rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
  space-3xl: 4.5rem
---

## Brand & Style

This design system embodies the seamless transformation of handwritten notes, sketches, and schedule intents into refined digital action ("Scanned. Reviewed. Pencil'd."). The aesthetic is rooted in tactile clarity merged with luminous glassmorphic modernism: crisp white note surfaces reminiscent of premium paper stock set against deep cosmic indigo canvases, punctuated by an incandescent multi-stop sunset gradient (golden amber, fiery tangerine, radiant coral, magenta, and spectral violet).

The visual language communicates effortless workflow capture, high precision, and creative vitality. Target users are creative professionals, high-velocity planners, students, and executives who balance messy real-world capture with meticulous digital scheduling. 

### Visual Tenets
- **Luminous Spectrum:** Interactive high-priority focal points leverage the full multi-stop spectrum gradient, evocative of dynamic pencil markings brought to life with ambient neon energy.
- **Translucent Depth (Frosted Surface Layers):** Modals, side sheets, floating navigation, and cards use layered frosted glass physics, tinted border bevels, and atmospheric glow rather than standard drop shadows.
- **Tactile Softness:** Balanced squircle contours and pill elements soften structured calendaring, lending an approachable yet engineered feel.

## Colors

The palette directly extrapolates the glowing pencil and calendar emblem. Colors are systematically organized into theme surfaces, neutral steps, brand chromatic accents, and multi-stop linear gradient formulations.

### Palette Definitions

#### Brand Gradient Ramp
- **Golden Yellow:** `#FFB800`
- **Vibrant Orange (Primary):** `#FF7A00`
- **Coral Pink:** `#FF4D6D`
- **Electric Magenta (Tertiary):** `#E02475`
- **Spectral Violet (Secondary):** `#9B51E0`
- **Deep Indigo Base (Neutral):** `#0F1026`

#### Gradient Tokens
- **`gradient-brand-primary`**: `linear-gradient(135deg, #FFB800 0%, #FF7A00 32%, #FF4D6D 65%, #9B51E0 100%)`
- **`gradient-brand-subtle`**: `linear-gradient(135deg, rgba(255, 184, 0, 0.15) 0%, rgba(255, 122, 0, 0.15) 35%, rgba(155, 81, 224, 0.15) 100%)`
- **`gradient-glass-border-dark`**: `linear-gradient(135deg, rgba(255, 255, 255, 0.22) 0%, rgba(255, 122, 0, 0.4) 40%, rgba(155, 81, 224, 0.4) 80%, rgba(255, 255, 255, 0.05) 100%)`
- **`gradient-glass-border-light`**: `linear-gradient(135deg, rgba(255, 122, 0, 0.35) 0%, rgba(155, 81, 224, 0.25) 100%)`

#### Dark Theme Surfaces (Default Mode)
- **`bg-canvas`**: `#0F1026` (Deep indigo space)
- **`bg-surface-lowest`**: `#090A18` (Recessed wells, dark codeblocks)
- **`bg-surface`**: `#15162E` (Primary paneling and calendar views)
- **`bg-surface-elevated`**: `#1D1F3C` (Cards, list rows, popovers)
- **`bg-glass`**: `rgba(29, 31, 60, 0.65)` with `backdrop-filter: blur(20px)`
- **`text-primary`**: `#FFFFFF`
- **`text-secondary`**: `#9A9EC2`
- **`text-muted`**: `#606488`
- **`border-hairline`**: `rgba(255, 255, 255, 0.08)`
- **`border-glass`**: `rgba(255, 255, 255, 0.15)`

#### Light Theme Surfaces
- **`bg-canvas`**: `#F7F7FA` (Crisp subtle alabaster)
- **`bg-surface`**: `#FFFFFF` (Pencil paper cardstock)
- **`bg-surface-elevated`**: `#FFFFFF`
- **`bg-surface-muted`**: `#EEF0F8`
- **`bg-glass`**: `rgba(255, 255, 255, 0.82)` with `backdrop-filter: blur(16px)`
- **`text-primary`**: `#0C0D1E`
- **`text-secondary`**: `#535777`
- **`text-muted`**: `#8E92B0`
- **`border-hairline`**: `rgba(15, 16, 38, 0.08)`
- **`border-glass`**: `rgba(15, 16, 38, 0.12)`

#### Semantic Status
- **Success:** `#10B981` (Bright mint emerald)
- **Warning:** `#FFB800` (Warm amber)
- **Danger:** `#EF4444` (Vivid crimson)
- **Info:** `#3B82F6` (Electric cobalt)

## Typography

Typography uses **Plus Jakarta Sans** across all structural tiers. Its geometric clarity, contemporary rounded terminals, and clear vertical rhythm echo the smooth curves of the signature pencil identity while maintaining rigorous legibility in dense calendar views and OCR scan reviews.

### Stylistic Guidelines
- **Gradient Text Clipping:** Hero banners and primary statistics allow background clipping of `gradient-brand-primary` using `-webkit-background-clip: text; color: transparent;`. This should be reserved for `display-lg`, key brand metrics, and milestone banners.
- **Numbers & Dates:** Always set numbers in tabular figures (`font-variant-numeric: tabular-nums`) within timeline schedules, duration counters, and calendar headers to prevent alignment jitter.
- **Upper Labels:** `label-sm` utilizes an uppercase transform and `0.06em` letter spacing for section sub-headers, tags, and status trackers (e.g., `SCANNED`, `REVIEWED`, `CONFIRMED`).

## Layout & Spacing

The layout model is built on an adaptable 8-point base grid system, structured around fluid viewport columns with rigid internal component spacing.

### Breakpoints & Canvas Bounds
- **Mobile (< 640px):** 4 columns, `margin: 1rem` (16px), `gutter: 1rem` (16px). Bottom sheets and fixed floating command dock take precedence over side panels.
- **Tablet (640px - 1024px):** 8 columns, `margin: 1.5rem` (24px), `gutter: 1.25rem` (20px). Split dual-pane layouts (Scan preview on left, agenda review list on right).
- **Desktop (>= 1024px):** 12 columns, maximum bounded container width of `1440px`, `margin: 2.5rem` (40px), `gutter: 1.75rem` (28px). Multi-column dashboard layout supporting navigation bar, daily timeline, and contextual review inspector.

### Spacing Application
- Use `space-xs` (6px) and `space-sm` (8px) for compact interior component gaps (icon-to-text labels, inline status dots).
- Use `space-md` (16px) for interior card padding and form control separation.
- Use `space-lg` (24px) for distinct card containers and modal margins.
- Use `space-2xl` and `space-3xl` for high-level page section transitions.

## Elevation & Depth

Visual depth is achieved through an optical fusion of frosted acrylic glass surfaces and chromatic edge glows, matching the backlit vibrancy of the brand icon.

### Depth Hierarchy

1. **Flat Canvas (Level 0):** Pure background canvas (`#0F1026` dark, `#F7F7FA` light).
2. **Surface / Card (Level 1):** 
   - *Dark Mode:* Background `rgba(21, 22, 46, 0.75)`, border `1px solid rgba(255, 255, 255, 0.08)`, shadow `0 4px 20px -2px rgba(5, 6, 16, 0.5)`.
   - *Light Mode:* Background `#FFFFFF`, border `1px solid rgba(15, 16, 38, 0.06)`, shadow `0 2px 12px rgba(15, 16, 38, 0.04)`.
3. **Elevated Floating Card / Scan Card (Level 2):**
   - *Dark Mode:* Background `rgba(29, 31, 60, 0.85)` with `backdrop-filter: blur(16px)`, border `1px solid rgba(255, 255, 255, 0.16)`, shadow `0 12px 32px -4px rgba(5, 6, 16, 0.7)`.
   - *Light Mode:* Background `rgba(255, 255, 255, 0.95)`, shadow `0 8px 24px -2px rgba(15, 16, 38, 0.08)`.
4. **Active Hero Overlays & Modals (Level 3):**
   - Border utilizes the multi-color gradient hairline (`gradient-glass-border-dark`).
   - Outer glow: `0 0 28px -4px rgba(255, 122, 0, 0.25), 0 20px 40px -8px rgba(0, 0, 0, 0.8)`.
5. **Interactive Glows (Focus/Hover):**
   - Interactive focus triggers a soft 4px volumetric outline: `0 0 0 3px rgba(255, 122, 0, 0.35)`.

## Shapes

The shape vocabulary employs squircle-like, rounded geometries that mirror the organic rounded casing of the calendar binder and pencil mark in the brand logo.

- **Base Radius (`rounded-md`, 0.5rem / 8px):** Checkboxes, inline badge tags, tooltips, and secondary nested cells.
- **Default Container Radius (`rounded-lg`, 1rem / 16px):** Standard cards, text input fields, dropdown menus, and list item hover blocks.
- **Large Surface Radius (`rounded-xl`, 1.5rem / 24px):** Calendar day containers, scanned document viewports, modal sheets, and side drawers.
- **Pill Radius (`rounded-full`, 9999px):** Primary Action Buttons (CTAs), tab switches, chip selectors, and status indicator pills.

## Components

### Buttons
- **Primary CTA:** Pill-shaped (`rounded-full`), filled with `gradient-brand-primary` (`#FFB800` to `#9B51E0`). Text is bold white `#FFFFFF` with a crisp drop shadow (`0 1px 2px rgba(0,0,0,0.3)`). Hover shifts gradient exposure and expands a warm orange underglow (`0 8px 24px rgba(255, 122, 0, 0.45)`).
- **Secondary Ghost:** Frosted translucent background (`rgba(255, 255, 255, 0.06)` in dark mode), crisp 1px border (`rgba(255, 255, 255, 0.14)`), white text. On hover, border turns into subtle gradient stroke.
- **Tertiary Text:** No background or border. Orange-to-magenta gradient text or solid bright amber.

### Chips & Badges
- **Status Badges:** Pill-shaped with compact padding (`4px 10px`). Uses 12% alpha tinted background paired with vibrant text (e.g., Scan in Progress: `rgba(255, 184, 0, 0.15)` bg with `#FFB800` text; Pencil'd: `rgba(155, 81, 224, 0.15)` bg with `#C084FC` text).
- **Filter Chips:** Height of 36px, `rounded-full`, soft glass outline. Active state transitions to solid subtle brand gradient fill.

### Input Fields & Search Bars
- **Surface:** In dark mode, `#15162E` background with a recessed inset shadow (`inset 0 2px 4px rgba(0, 0, 0, 0.35)`). In light mode, `#FFFFFF` with `#E2E4EE` border.
- **Typography:** `body-md` (14px). Placeholders set to `text-muted`.
- **Focus State:** 1px border shifts to bright coral (`#FF4D6D`) accompanied by a non-intrusive outer atmospheric halo (`box-shadow: 0 0 0 3px rgba(255, 77, 109, 0.2)`).

### Cards & Calendar Panels
- **Standard Card:** Smooth 16px radius (`rounded-lg`), frosted acrylic backdrop, hairline border.
- **The "Scanned Item" Review Card:** High-contrast card featuring a split left-hand scan indicator border colored in the brand gradient, accompanied by editable extracted title, time, and categorized tags.
- **Calendar Day Cell:** Rounded corners (12px), active day highlighted with a glowing violet ring and orange schedule pips.

### Lists & Activity Rows
- **List Rows:** Separated by invisible dividers utilizing `space-xs` padding; rows highlight on hover with `rgba(255, 255, 255, 0.04)` fill and 12px rounded corners.
- **Leading Indicator:** Bullet icons, category stamps, or OCR confidence meters styled with amber-to-purple gradient icons.

### Checkboxes & Radios
- **Checkbox:** 20px by 20px, `rounded-md` (6px radius). When checked, filled with `gradient-brand-primary` showing a crisp white checkmark SVG.
- **Radio:** Circular, active state reveals an inner gradient dot centered within a luminous violet concentric ring.