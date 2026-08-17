---
name: Vital Flow
colors:
  surface: '#fff8f7'
  surface-dim: '#ead5d7'
  surface-bright: '#fff8f7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fff0f1'
  surface-container: '#fee9eb'
  surface-container-high: '#f8e3e5'
  surface-container-highest: '#f3dde0'
  on-surface: '#24191a'
  on-surface-variant: '#5c3f3d'
  inverse-surface: '#3a2d2f'
  inverse-on-surface: '#ffecee'
  outline: '#916f6c'
  outline-variant: '#e6bdba'
  surface-tint: '#c00020'
  primary: '#960017'
  on-primary: '#ffffff'
  primary-container: '#c30121'
  on-primary-container: '#ffd1cd'
  inverse-primary: '#ffb3ae'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e4e2e1'
  on-secondary-container: '#656464'
  tertiary: '#004b7e'
  on-tertiary: '#ffffff'
  tertiary-container: '#0063a4'
  on-tertiary-container: '#c3ddff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad7'
  primary-fixed-dim: '#ffb3ae'
  on-primary-fixed: '#410005'
  on-primary-fixed-variant: '#930016'
  secondary-fixed: '#e4e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#d1e4ff'
  tertiary-fixed-dim: '#9dcaff'
  on-tertiary-fixed: '#001d35'
  on-tertiary-fixed-variant: '#00497b'
  background: '#fff8f7'
  on-background: '#24191a'
  surface-variant: '#f3dde0'
typography:
  display-lg:
    fontFamily: Georgia
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Georgia
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-md:
    fontFamily: Georgia
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-sm:
    fontFamily: Georgia
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  button:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 64px
---

## Brand & Style

This design system is built on the pillars of empathy, reliability, and clinical excellence. Designed for a blood donation platform, it balances the urgency of healthcare with a calming, human-centric aesthetic. The visual style is **Modern Corporate** with a warm, approachable twist, utilizing a soft surface palette to reduce the sterile feel often associated with medical applications.

The target audience ranges from first-time donors seeking reassurance to regular contributors and medical staff requiring efficiency. The UI evokes a sense of "Quiet Authority"—it is professional enough to trust with one's health data, yet warm enough to encourage community and altruism.

Key stylistic markers include:
- **Serif/Sans Pairing:** Using classic serifs for storytelling and information hierarchy, paired with high-legibility sans-serifs for functional tasks.
- **Organic Softness:** Pill-shaped interactive elements and generous rounded corners on containers to create a non-threatening environment.
- **Warm Surfaces:** Moving away from pure white to a tinted, blood-plasma-inspired "soft pink" background to reduce eye strain and increase perceived warmth.

## Colors

The palette is anchored by a deep, authoritative red that symbolizes life and urgency. This is balanced by a sophisticated near-black for text and a calming medical blue for secondary actions and trust-building elements.

- **Primary (#C30121):** Used for critical CTAs, brand identity, and urgent alerts. It represents the "pulse" of the app.
- **Secondary (#2B2B2B):** Provides high-contrast grounding for primary typography and navigation elements.
- **Tertiary (#0D68AA):** Utilized for information cues, educational content, and links to establish a sense of medical professionalism.
- **Neutral (#8E7D7F):** A desaturated, warm grey used for borders, secondary labels, and iconography.
- **Surface (#FDF3F3):** The foundation of the UI. This warm off-white creates a soft, inviting backdrop that separates the experience from generic "tech" apps.

## Typography

This system employs a traditional/modern hybrid approach. **Georgia** is used for headlines to convey a sense of history, trust, and editorial quality—essential for medical information. **Inter** is the workhorse for all functional elements, providing maximum legibility across all screen sizes.

On mobile devices, `display-lg` should scale down to 36px. All serif headlines should maintain a slightly tighter letter-spacing to ensure they feel cohesive rather than fragmented. Inter should be used exclusively for input fields, button labels, and dense data tables to maintain a systematic and utilitarian feel during the donation booking process.

## Layout & Spacing

The layout follows a **Fluid Grid** model based on a 4px baseline unit. 

- **Mobile:** 4-column grid with 16px margins and 16px gutters.
- **Desktop:** 12-column grid with a maximum content width of 1280px. Margins expand to 64px to provide significant whitespace, reinforcing the "minimalist" and "clean" brand promise.

Spacing follows a linear scale. Use `md` (16px) for standard grouping and `lg` (24px) for separating major content blocks. Vertical rhythm is critical; ensure headline-to-body spacing is consistently `sm` (8px) to keep the editorial feel of the typography.

## Elevation & Depth

Visual hierarchy is achieved through **Tonal Layers** and extremely soft **Ambient Shadows**. Because the background is a warm surface (#FDF3F3), elevation levels are defined by subtly lighter or darker containers rather than harsh drop shadows.

- **Level 0 (Base):** The surface color (#FDF3F3).
- **Level 1 (Cards):** Pure white (#FFFFFF) background with a very diffuse, low-opacity shadow (4% opacity #8E7D7F) with a 12px blur.
- **Level 2 (Modals/Overlays):** Pure white background with a slightly more defined shadow (8% opacity #2B2B2B) and a 24px blur.

Avoid using borders for elevation unless they are low-contrast (#EAE0E0) to maintain the "soft" feel of the system.

## Shapes

The shape language is defined by the **Pill/Capsule** form factor. This choice removes the "sharp edges" often associated with medical needles and hospitals, replacing them with friendly, approachable curves.

- **Interactive Elements:** Buttons, chips, and tags must always use a fully rounded (9999px) corner radius.
- **Containers:** Content cards and input fields use a `rounded-lg` (16px) radius to maintain harmony with the pill-shaped buttons without becoming overly circular.
- **Icons:** Use rounded caps and joins for all iconography to mirror the typography and shape language.

## Components

### Buttons
- **Primary:** Pill-shaped, Primary Red background, White text. No shadow on rest, subtle lift on hover.
- **Secondary:** Pill-shaped, Transparent background, Primary Red border (2px), Red text.
- **Tertiary/Ghost:** Pill-shaped, Transparent background, Tertiary Blue text.

### Input Fields
- Background: Pure White.
- Border: 1px Solid Neutral (#8E7D7F) at 30% opacity.
- Border-radius: 12px.
- Focus State: 2px border using Tertiary Blue (#0D68AA).

### Chips & Tags
- Used for blood types (e.g., A+, O-).
- Small pill-shaped containers with 12px horizontal padding.
- Light tint of the Primary color for positive statuses; light tint of Neutral for inactive states.

### Cards
- Background: Pure White.
- Corner Radius: 16px.
- Padding: 24px.
- Use for donor stats, clinic locations, and appointment summaries.

### Progress Indicators
- Use a thick (8px) line with pill-shaped caps.
- Background track: Neutral at 10% opacity.
- Fill: Primary Red for urgency/progress; Tertiary Blue for informational steps.