# CalTracker Functional Parity Design

## Goal

Restore and extend the functionality lost during the visual redesign so the
native iOS app faithfully reproduces the deployed CalorieAI web application's
workflows while retaining local-only storage and Apple-native interaction.

## Migration

The existing SwiftData store must migrate without deleting profiles, meals,
water, weight, recipes, plans, or shopping items. New persisted properties are
optional or have declaration defaults. Existing meals remain valid without an
image or structured food breakdown.

Images are JPEG files in Application Support rather than large SwiftData blobs.
Models store relative filenames. Deleting a meal or recipe also removes its
owned image.

## Data Model Additions

`MealEntry` gains:

- `imageFilename`
- `foodsJSON`
- `analysisNotes`
- `analysisConfidence`
- `analysisModel`
- `createdAt`

`Recipe` gains:

- `imageFilename`
- `sourceURL`
- `foodsJSON`
- `fiberPerServing`

`MealPlanEntry` gains:

- `servings`
- a stable recipe identifier where available

`BuffetSession` stores:

- start and completion timestamps
- piece count
- Nigiri, Maki, Tempura, Gyoza, Postre and Otros counts
- calories and macros
- whether Gemini or local estimation was used
- summary and saved-meal identifier

## Shared Visual Fix

Tinted Liquid Glass must not paint entire content surfaces. Cards use neutral
glass/material. Accent colors are limited to borders, icon wells, progress
fills, chips and primary actions. Interactive glass is reserved for controls.

The duplicated floating blue add button is removed. Registration remains the
single center tab action.

## Home

The balance card includes a large calorie ring and three small macro rings for
carbohydrates, protein and fat.

Coach IA uses the original violet gradient button, compact loading state and
generated advice card.

The red home callout starts a real buffet session. Active sessions expose a
persistent bar above the tab bar and open a full-screen counter:

- elapsed timer
- total piece button
- per-category increment/decrement
- local live estimate
- Gemini analysis or local estimate at completion
- editable breakdown
- save as a meal or discard

Hydration uses a custom animated gradient track with 500 ms progress animation
and glow. Buttons persist 250 ml changes.

Meal cards display their saved photo, structured food breakdown and a visible
delete action with confirmation.

## Food Logging

Photo analysis produces an editable `AnalysisDraft`, not immediate meal rows.
The review screen shows:

- model used and confidence
- calorie and macro totals
- every detected food
- editable names, portions and nutrients
- notes
- `Repetir` to discard and rescan
- `Guardar comida` to save one meal with image and structured JSON

Barcode and restaurant selections enter the same review editor before saving.
The restaurant catalog includes searchable local entries for the chains present
in the original application and remains usable offline.

## Recipes

Recipe creation accepts a photo from camera or library. Cards and details render
the persisted photo.

Recipe details show ingredients, per-ingredient nutrition, instructions and a
change-photo action.

URL import fetches the page directly, extracts readable recipe content and uses
Gemini to normalize name, servings, ingredients, instructions and nutrition.
The user reviews and edits the imported recipe before saving.

The top calendar button opens the weekly planner. Plans select a recipe, meal
type and servings. The shopping list can be populated from planned recipe
ingredients and remains editable.

## History And Profile

History meal rows display photos and offer visible deletion. Buffet records and
computed achievements are shown from real local data.

When a Gemini key exists, the secure field displays a masked placeholder. Saving
an empty masked field does not overwrite the stored key. The user can replace or
delete it explicitly.

## Verification

- Unit tests cover draft totals, buffet estimation and migration-compatible
  decoding helpers.
- Xcode 26 builds the app and test target for iOS 17.
- Simulator screenshots cover Home, Log review, Buffet, Recipes, Planner,
  History and Profile in dark mode plus Home in light mode.
- A release IPA is verified for version metadata, Payload structure and release
  hash before SideStore publication.
