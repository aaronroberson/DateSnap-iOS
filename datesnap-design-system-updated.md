# DateSnap Design System

## Art Direction

DateSnap should feel like a premium consumer utility: fast, trustworthy, cinematic, and easy to act on. The attached logo suggests a glossy glassmorphism aesthetic with forward motion, neon scan energy, and a layered calendar-plus-capture metaphor, so the UI should translate that into restrained contrast, luminous accent color, translucent surfaces, and confident simplicity rather than skeuomorphic decoration. [file:23]

Core design keywords:
- Fast capture.
- Premium clarity.
- Ambient glass.
- Confident guidance.
- Forward momentum. [file:23]

## Color Palette

All colors should use **display-p3** where supported, with sRGB fallbacks. The logo introduces a cooler electric-blue calendar layer, a warmer magenta-to-orange scan layer, and soft glass highlights, so the product palette should be built around a dark cinematic base with vibrant but controlled accents. [file:23]

### Semantic Tokens

| Variable | Value | Usage |
|---|---|---|
| `--color-background` | `#050816` | Primary app background; deep midnight navy, softer and richer than pure black. [file:23] |
| `--color-foreground` | `#F7F8FF` | Primary text on dark surfaces. [file:23] |
| `--color-card` | `rgba(18, 24, 52, 0.72)` | Glass card background; modals, sheets, elevated surfaces. [file:23] |
| `--color-card-foreground` | `#F7F8FF` | Text on cards and overlays. [file:23] |
| `--color-primary` | `#7CFFEA` | Primary action highlight for focused states, toggles, and key confirmations; derived from the logo’s cyan light tile. [file:23] |
| `--color-primary-foreground` | `#07111F` | Text/icons on bright primary surfaces. [file:23] |
| `--color-secondary` | `#5B7CFF` | Secondary accent for navigation, active tabs, and cool emphasis. [file:23] |
| `--color-secondary-foreground` | `#F7F8FF` | Text on secondary accent surfaces. [file:23] |
| `--color-muted` | `rgba(255,255,255,0.08)` | Secondary surface fills, segmented controls, inactive chips. [file:23] |
| `--color-muted-foreground` | `#A8B0D4` | Secondary text, helper text, metadata. [file:23] |
| `--color-border` | `rgba(173, 195, 255, 0.18)` | Hairlines, card outlines, input borders. [file:23] |
| `--color-accent` | `#FF4FB3` | Emotional accent for highlights, active scan moments, and premium emphasis. [file:23] |
| `--color-accent-2` | `#FF8A3D` | Motion accent for streaks, urgency, and CTA energy. [file:23] |
| `--color-success` | `#46E39A` | High-confidence extraction, saved events, success states. |
| `--color-warning` | `#FFBE55` | Medium-confidence extraction, needs review. |
| `--color-error` | `#FF6B7A` | Low-confidence extraction, parsing problems, destructive actions. |
| `--color-info` | `#63B8FF` | Informational tips and assistive guidance. |
| `--color-overlay` | `rgba(4, 8, 22, 0.72)` | Backdrop overlays for sheets and dialogs. [file:23] |
| `--color-glass-highlight` | `rgba(255,255,255,0.22)` | Top-edge glass reflections and keyline highlights. [file:23] |
| `--color-scan-gradient` | `linear-gradient(90deg, #FF8A3D 0%, #FF4FB3 48%, #7B61FF 100%)` | Scan beams, hero moments, premium highlights. [file:23] |
| `--color-brand-gradient` | `linear-gradient(135deg, #32C5FF 0%, #5B7CFF 30%, #9D4DFF 62%, #FF4FB3 82%, #FF8A3D 100%)` | Hero art, icons, active states, brand moments. [file:23] |

### Surface Model

| Layer | Token | Intent |
|---|---|---|
| App shell | `--color-background` | Full-screen base |
| Raised surface | `--color-card` | Cards, sheets, floating panels |
| Subtle fill | `--color-muted` | Inputs, pills, inactive controls |
| Hairline | `--color-border` | Structural separation |
| Glow edge | `--color-glass-highlight` | Premium depth, not heavy borders |

### Light Mode

Light mode should not be a simple inversion. It should preserve the brand’s airy futuristic feel with frosted whites, cool indigo text, and neon accents used sparingly.

| Variable | Value | Usage |
|---|---|---|
| `--color-background` | `#F6F8FF` | Light app background |
| `--color-foreground` | `#11162A` | Primary text |
| `--color-card` | `rgba(255,255,255,0.74)` | Glass cards on light surfaces |
| `--color-card-foreground` | `#11162A` | Text on cards |
| `--color-muted` | `rgba(91,124,255,0.08)` | Secondary surface fill |
| `--color-muted-foreground` | `#5F678C` | Secondary text |
| `--color-border` | `rgba(72, 93, 166, 0.18)` | Inputs and separators |
| `--color-overlay` | `rgba(245,248,255,0.72)` | Frosted backdrops |

## Typography

The current type system should be updated to match the logo. The attached mark uses a bold, modern sans for “Date” and a high-personality script for “Snap,” which works well for branding but should not be copied literally into product UI. The app UI itself should feel modern, crisp, and highly legible, with a premium grotesk sans as the workhorse and a softer display face only for selective marketing moments. [file:23]

- **Display font:** `Sora, ui-sans-serif, sans-serif` — hero numbers, marketing headers, feature callouts.
- **UI sans font:** `Inter, Instrument Sans, -apple-system, BlinkMacSystemFont, sans-serif` — body text, controls, labels, settings, data.
- **Optional wordmark display only:** retain custom brand lockup artwork from the logo for splash/marketing use; do not typeset this in product screens. [file:23]
- **Font weights:** 400, 500, 600, 700, 800.
- **Tracking:** slightly tightened on large headlines (`-0.02em`), neutral on body.
- **Line-height:** 1.05–1.15 for large display text; 1.35 for headings; 1.45–1.6 for body.

### Recommended Scale

| Token / Size | Usage |
|---|---|
| `11px` | Tiny metadata, confidence labels, overlines |
| `12px` | Helper text, secondary captions |
| `13px` | Filter chips, compact buttons |
| `14px` | Default button text, nav labels, annotations |
| `16px` | Default body text |
| `18px` | Strong body / compact section headings |
| `20px` | Sheet titles, card headings |
| `24px` | Section titles |
| `30px` | Hero section titles in app |
| `38px` | Marketing hero or onboarding emphasis |

## Brand Expression

The new visual language should move away from editorial serif cues and instead embrace a polished glass-tech product style inspired by the attached logo. That means translucent layers, soft inner highlights, smooth gradients, luminous edge rims, and controlled motion lines that imply capture and speed without overwhelming the utility of the interface. [file:23]

Guidelines:
- Use dark navy as the dominant field, never pure black.
- Use gradient color only for brand moments, CTAs, active scan states, and premium highlights.
- Keep most production UI text white, soft white, or cool muted lavender-gray.
- Use blur and translucency sparingly; information clarity always wins over visual effects.
- Prefer one focal glow per viewport rather than many competing glows. [file:23]

## Icon System

Keep the 24x24 SVG icon approach, but update the style language:
- Stroke width: `1.75`–`1.9`.
- Rounded ends and joins.
- Slightly squarer geometry than generic iOS icons to match the logo’s rounded-rectangle panel language. [file:23]
- Use duotone or gradient fills only for hero/illustrative states; navigation icons stay single-color for clarity.

### Revised Icon Set

| Name | Meaning/Usage |
|---|---|
| `home` | Main dashboard |
| `inbox` | Review queue / extracted events |
| `settings` | Settings |
| `spark` | High confidence |
| `photo` | Photo library import |
| `scan-frame` | Camera / screenshot scan action |
| `share` | Share to DateSnap |
| `chevron-right` | Navigation |
| `calendar-grid` | Event/date object |
| `pin` | Location |
| `clock` | Time |
| `bell` | Reminders/alerts |
| `check` | Saved/confirmed |
| `x` | Dismiss / not an event |
| `lock` | Privacy |
| `plus` | Add manually |
| `note` | Extra details |
| `wand` | Smart extraction |
| `scan-line` | Active recognition state |
| `warning` | Needs review |
| `star` | Featured/premium |

## Core Components

### DateBadge
- Width: 56px, Height: 68px.
- Border-radius: 16px.
- Background: `var(--color-card)`.
- Border: `1px solid var(--color-border)`.
- Add subtle inner top highlight using `--color-glass-highlight`. [file:23]
- Month in compact uppercase sans; day in bold sans, not italic serif.
- Selected state can use a cool-to-warm gradient edge or glow.

### Header
- Align to a more app-native structure: title and support text stacked left, action cluster right.
- Eyebrow: 11px uppercase, semi-bold, muted foreground.
- Page title: 30px `Sora`, weight 700.
- Avoid italics in core UI.

### TabBar
- Fixed bottom with glassmorphism shell.
- Height: 84–88px including safe area treatment.
- Background: `rgba(10, 14, 30, 0.72)` with blur 20px.
- Top border: 1px solid `var(--color-border)`.
- Active tab can use a soft cyan or magenta glow pill behind the icon/label. [file:23]

### ActionCard / Primary Action
- Min-height: 156px.
- Border-radius: 24px.
- Background: layered gradient over `var(--color-card)` for hero variant; standard variant stays glass-neutral.
- Padding: 20px–22px.
- Include subtle scan-line or glow accent only on the primary card. [file:23]
- Active state: scale to 0.985 plus glow compression.

### HeroCard
- Min-height: 140px.
- Border-radius: 26px.
- Use premium glass panel styling with one ambient gradient orb or streak.
- Count badge should be brighter and more dimensional, using `--color-primary` or brand gradient.
- Label: 11px uppercase, semibold, muted.

### ScanSheet / Scanning State
- This is the signature brand moment.
- Backdrop: `var(--color-overlay)` with strong blur.
- Sheet: glass panel with dark translucent base and luminous top edge.
- Rounded top corners: 32px.
- Add a horizontal animated scan beam using `--color-scan-gradient`. [file:23]
- OCR confidence cards should glow subtly based on success/warning/error.

### Toggle Card
- Min-height: 84px.
- Glass row background with separator only where needed.
- Switch track: muted base.
- Switch active state: cyan core with magenta glow edge for a more branded feel.

### Save Button
- Width: 100%, min-height: 56px.
- Border-radius: 28px.
- Primary version: filled bright gradient or cyan emphasis depending on context.
- Secondary version: glass surface with border.
- Saved state: cool glass fill with check icon in success green.

### Privacy Note
- Padding: 12px 16px.
- Border-radius: 16px.
- Background: `rgba(99, 184, 255, 0.08)` or neutral glass.
- Border: `1px solid rgba(99, 184, 255, 0.18)`.
- Icon: lock, 14px, info blue.

## Motion System

The logo already implies movement through scan streaks and layered perspective, so animation should reinforce momentum, not bounce or wobble. Motion should feel smooth, directed, and lightly cinematic. [file:23]

| Transition | Timing | Easing |
|---|---|---|
| Fade in | 0.24s | cubic-bezier(0.22, 1, 0.36, 1) |
| Slide up | 0.34s | cubic-bezier(0.16, 1, 0.3, 1) |
| Glass press | 0.16s | ease-out |
| Scan sweep | 1.8s | linear infinite |
| Glow pulse | 2.4s | ease-in-out infinite |
| Tab transition | 0.22s | cubic-bezier(0.22, 1, 0.36, 1) |

Animation principles:
- Horizontal motion is more on-brand than vertical bounce. [file:23]
- Scanning indicators should pass through content, not flash randomly.
- Use blur and glow transitions with restraint.
- Respect `prefers-reduced-motion` by simplifying scan sweeps into opacity fades.

## Dark Mode

Dark mode should be the primary authored experience. The logo’s dark presentation feels more premium, more cinematic, and more emotionally aligned with trust and focus. [file:23]

Rules:
- Design dark first.
- Use light mode as a polished alternate environment, not a mirrored inversion.
- Preserve accent vibrancy in both modes, but reduce glow intensity in light mode.
- Avoid heavy shadows in dark mode; use layered glow and translucent edges instead.

## Accessibility

- All core text/background combinations must meet WCAG AA.
- Do not place white text directly over live gradients unless a solid or blurred backing layer exists.
- Keep decorative glow separate from the actual control boundary.
- Touch targets remain minimum 44px.
- Motion states must remain understandable without color alone.
- Confidence states require icon + label + color, not color only.

## Component Mapping to SwiftUI

| React Component | SwiftUI Equivalent | Notes |
|---|---|---|
| `Header` | `VStack` + `ToolbarItem` | Use `Sora` for titles, standard sans for support text |
| `TabBar` | `TabView` with custom material background | Use blur/material plus gradient active state |
| `ActionCard` | `RoundedRectangle` with layered overlays | Prefer glass fill + glow edge |
| `HeroCard` | `RoundedRectangle` + gradient overlays | Use one ambient accent orb or streak |
| `DateBadge` | `ZStack` + `RoundedRectangle` + `VStack` | 56×68pt, sans-based date treatment |
| `Toggle Card` | `HStack` + styled `Toggle` | Match glass row styling |
| `Save Button` | `Button` with capsule shape | Filled gradient or glass secondary variant |
| `Privacy Note` | `HStack` with icon and copy | Soft info tint treatment |
| `ScanSheet` | `.sheet` with custom background material | Signature scan beam animation |
| `TabBar badge` | `Circle` overlay | Use accent or success tone based on state |

## Updated CSS Variable Example

```css
:root {
  --color-background: #050816;
  --color-foreground: #F7F8FF;
  --color-card: rgba(18, 24, 52, 0.72);
  --color-card-foreground: #F7F8FF;
  --color-primary: #7CFFEA;
  --color-primary-foreground: #07111F;
  --color-secondary: #5B7CFF;
  --color-secondary-foreground: #F7F8FF;
  --color-muted: rgba(255,255,255,0.08);
  --color-muted-foreground: #A8B0D4;
  --color-border: rgba(173, 195, 255, 0.18);
  --color-accent: #FF4FB3;
  --color-accent-2: #FF8A3D;
  --color-success: #46E39A;
  --color-warning: #FFBE55;
  --color-error: #FF6B7A;
  --color-info: #63B8FF;
  --color-overlay: rgba(4, 8, 22, 0.72);
  --color-glass-highlight: rgba(255,255,255,0.22);
  --color-scan-gradient: linear-gradient(90deg, #FF8A3D 0%, #FF4FB3 48%, #7B61FF 100%);
  --color-brand-gradient: linear-gradient(135deg, #32C5FF 0%, #5B7CFF 30%, #9D4DFF 62%, #FF4FB3 82%, #FF8A3D 100%);
}
```

## Design Direction Summary

The old system leaned monochrome/editorial; the updated system should feel like a premium AI-powered consumer product with momentum, glass depth, and color confidence. The attached logo strongly supports a repositioning toward a darker, more modern, more energetic interface with cleaner sans typography, luminous gradients, and highly legible product surfaces. [file:23]
