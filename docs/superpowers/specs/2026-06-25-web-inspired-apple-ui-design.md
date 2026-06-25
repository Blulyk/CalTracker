# CalTracker Web-Inspired Apple UI Design

## Objective

Redesign the native iOS application so it carries the visual identity and
information hierarchy of the existing CalorieAI web application while behaving
like a polished Apple platform product. The redesign does not embed web content
and does not replace real local data with fixtures.

## Visual Language

- Default to a deep near-black canvas with subtle warm highlights behind major
  content areas. Light mode remains supported with semantic equivalents.
- Use orange for calories and primary nutrition actions, blue for hydration and
  the central add action, violet for Gemini, green for positive progress, and
  red only for excess or destructive actions.
- Use large, confident numeric typography and compact uppercase eyebrow labels.
- Use rounded dark surfaces with thin semantic borders. On iOS 26, controls and
  selected navigation surfaces use native Liquid Glass. On iOS 17 and 18 they
  use system materials with restrained borders.
- Do not reproduce browser chrome, HTML layout quirks, or non-native form
  controls. Buttons, sheets, pickers, menus, navigation and accessibility remain
  SwiftUI-native.

## App Shell

The application uses four persistent destinations:

1. Inicio
2. Recetas
3. Historial
4. Perfil

A prominent centered blue add button presents the logging experience. Each tab
keeps an independent `NavigationStack`. The tab bar uses native system behavior;
the center action is visually elevated without replacing system navigation with
a custom gesture implementation.

## Inicio

The top area contains a compact greeting, full date, profile monogram and a
seven-day date strip. The selected day uses a raised glass capsule.

The daily summary presents:

- A large consumed calorie number and remaining calories.
- A prominent circular balance card with progress percentage.
- Three macro values aligned below the ring.
- Two compact cards for streak and Gemini coach.
- A warm red buffet session callout.
- A blue hydration card with progress and decrement/increment actions.
- A weight card with a clear registration action.
- Today's meals grouped by meal type, or a strong empty state leading to Log.

All values come from SwiftData queries for the selected date.

## Registro

The logging sheet mirrors the web flow:

- Horizontal meal-type selector.
- Segmented source selector for photo, barcode and manual entry.
- Large photo target with gallery selection and camera/scanner actions.
- Recipe shortcut and recent food list.
- Editable Gemini and Open Food Facts results before persistence.

The flow uses native sheets, PhotosPicker, camera permissions and SwiftUI
controls. Loading, missing-key, network and no-product states remain explicit.

## Recetas And Plan

The second tab opens with Recetas because it is visually central in the web
application. It includes search, create/import actions, rich recipe cards,
macronutrient chips, expandable details and a primary log-as-meal action.

A top segmented control switches between Recetas, Semana and Compra so the
existing native planning and shopping capabilities remain available without
adding another persistent tab.

Recipe cards use a rich color treatment when no local image exists. They never
claim to show a food photograph that the user did not provide.

## Historial

History starts with month navigation and a Calendario/Semana switch. The
calendar grid marks:

- orange: logged nutrition
- red: calorie target exceeded
- blue: water logged
- white emphasis: selected or current day

Below it, the selected day's calorie progress, hydration, meals and weight trend
use real local entries. Charts remain native Swift Charts.

## Perfil

Profile becomes a scrollable dashboard rather than a stock settings form:

- Header with profile monogram and local-only identity.
- Gemini key card.
- Body metrics card.
- Goal choice tiles.
- Activity level rows with selected-state checkmark.
- Calculated target card with calories, BMI, TDEE, macros and estimated duration.
- Intermittent fasting and carbohydrate cycling cards.
- Privacy and destructive data controls.

Editable fields use native text fields and pickers inside the designed surfaces.

## Components

Shared components live in `DesignSystem.swift`:

- app background
- surface/card styles
- eyebrow labels
- icon badges
- metric tiles
- pill/chip styles
- primary and secondary actions
- week strip
- section headers

Repeated components have stable dimensions and Dynamic Type-safe layouts.

## Accessibility And Performance

- Preserve Dynamic Type and VoiceOver labels for rings, charts and icon buttons.
- Respect Reduce Motion.
- Use lazy stacks for long scroll content.
- Keep SwiftData filtering outside deeply repeated view bodies.
- Avoid custom blur layers and continuously animated backgrounds.
- Ensure text contrast remains sufficient in dark and light appearances.

## Verification

- Build with Xcode 26 for an iOS 17 simulator and iPhoneOS Release.
- Render onboarding and the four primary tabs at iPhone 16 Pro dimensions.
- Inspect screenshots for clipping, overlapping, empty canvases and incorrect
  color behavior.
- Verify the SideStore IPA archive and update the source only after visual and
  build checks pass.
