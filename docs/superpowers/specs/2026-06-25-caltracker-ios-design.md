# CalTracker iOS Design

## Product Definition

CalTracker is a native iPhone calorie and nutrition tracker derived from the
functional scope of CalorieAI, but it does not embed, display, or depend on the
existing web application or Umbrel server.

The application runs on iOS 17 or later. All profiles, meals, photos, recipes,
plans, shopping items, weight logs, water logs, preferences, and calculated
goals are stored locally on the device. There are no accounts, backend,
telemetry, iCloud synchronization, or Umbrel dependency.

Google Gemini remains the only remote AI service. Each user supplies a personal
Gemini API key, stored in Keychain. Open Food Facts is used directly for barcode
lookups. The app remains usable without either service for browsing and editing
previously stored data, manual food logging, water, weight, recipes, planning,
and shopping.

## Identity

- Product name: CalTracker
- Minimum OS: iOS 17
- Platforms: iPhone first; layouts must remain valid on iPad without a separate
  iPad-specific experience.
- Brand: blue and orange
- Icon: a blue nutritional progress ring, one orange progress segment, and a
  centered leaf. It must remain legible at notification and Settings icon sizes.
- Visual direction: restrained Apple-native health utility. Use iOS 26 native
  Liquid Glass APIs where available. On iOS 17 and iOS 18, use system materials,
  vibrancy, subtle borders, and semantic colors without attempting to imitate
  unsupported optical effects.

## Navigation

The root is a five-tab SwiftUI `TabView`:

1. Today
2. Log
3. History
4. Plan
5. Profile

Each tab owns an independent `NavigationStack`. Modal flows use enum-driven
`sheet(item:)` or `fullScreenCover(item:)` presentation rather than unrelated
boolean flags.

## Onboarding And Local Profile

The first launch replaces web registration with a local profile setup flow.

Required information:

- Display name
- Age
- Sex used for the metabolic formula
- Height in centimeters
- Current weight in kilograms
- Target weight
- Activity level: sedentary, light, moderate, active, very active
- Goal: lose, maintain, gain

Optional setup:

- Gemini API key
- Daily calorie goal override
- Intermittent fasting
- Carb cycling and training days

The user can skip the Gemini key and enter it later. Features requiring Gemini
must show a direct explanation and route to the Keychain-backed key editor.

The profile is a single local `UserProfile` record. Future AI prompts may use
only the profile fields relevant to the requested analysis. The UI must explain
which information is sent to Gemini.

## Goal Calculation

Goal calculations are local and deterministic:

- Mifflin-St Jeor BMR:
  - Male: `10 * weight + 6.25 * height - 5 * age + 5`
  - Female: `10 * weight + 6.25 * height - 5 * age - 161`
- Activity multipliers:
  - Sedentary: 1.2
  - Light: 1.375
  - Moderate: 1.55
  - Active: 1.725
  - Very active: 1.9
- Goal adjustment:
  - Lose: -500 kcal
  - Maintain: 0 kcal
  - Gain: +300 kcal
- Minimum calculated goal: 1200 kcal
- Protein:
  - Gain: 2.0 g per kg
  - Other goals: 1.8 g per kg
- Fat: 25 percent of calories divided by 9
- Carbohydrates: remaining calories after protein and fat, divided by 4
- BMI and estimated weeks to goal are calculated locally.

The user may override calorie and macro goals. The app keeps calculated and
manual targets distinct so recalculation never silently overwrites a manual
choice.

When sufficient meal and weight history exists, CalTracker may show an adaptive
calorie recommendation based on the user's observed trend. This is presented as
a suggestion with its difference from the active goal. It never changes the
goal without an explicit user action.

## Today

The Today tab is the operational dashboard.

It contains:

- Date selector with previous and next day navigation
- Main calorie progress ring
- Consumed, remaining, and goal calories
- Protein, carbohydrate, fat, and fiber progress
- Active streak
- Weight summary and quick weight entry
- Water progress and quick-add controls
- Intermittent fasting status and countdown when enabled
- Carb cycling status and the active training/rest target
- AI coach card
- Meals grouped into breakfast, lunch, dinner, and snack
- Quick action to log food
- Delete and edit actions for meals

The dashboard uses real SwiftData queries and derived totals. No placeholder or
demo nutrition values may appear in production states.

### AI Coach

The Coach sends Gemini:

- Local profile summary relevant to nutrition
- Current daily goal
- Current consumed calories and macros
- Optionally the names of today's foods

It requests one or two concise, actionable sentences. The response is ephemeral
by default and may be refreshed manually. API errors, quota limits, and missing
keys must have distinct user-facing states.

## Logging Food

The Log tab supports four entry routes:

1. Photo analysis
2. Barcode
3. Restaurant and buffet tools
4. Manual or saved recipe entry

Every route ends in the same editable meal review screen before persistence.

### Photo Analysis

Flow:

1. Capture with the native camera or choose from Photos.
2. Correct orientation and compress the image.
3. Send the compressed image directly to Gemini using the user's Keychain key.
4. Decode a strict JSON response.
5. Present detected foods, portions, calories, protein, carbohydrates, fat,
   fiber, confidence, suggested meal type, and assumptions.
6. Let the user edit every value.
7. Save the confirmed meal and a compressed local image.

Gemini model fallback order:

1. `gemini-2.5-flash-lite`
2. `gemini-2.5-flash`
3. `gemini-2.0-flash`

Low-confidence Flash Lite results may automatically retry with Flash. The app
must distinguish invalid JSON, no food detected, authentication failure, quota
limits, service overload, cancellation, and offline errors.

Images are resized to a sensible maximum dimension and compressed before
upload. The original camera asset is not copied into app storage. The compressed
history image is retained locally, with an optional setting to delete meal
photos after 30 days.

### Barcode

The barcode scanner uses AVFoundation and supports common EAN and UPC formats.
It queries Open Food Facts directly using:

`https://world.openfoodfacts.org/api/v2/product/{code}.json`

The result includes localized product name, brand, serving quantity, unit,
calories, protein, carbohydrates, fat, fiber, per-100-g values, image, and
barcode. The review screen lets the user change serving size and recalculates
nutrients from per-100-g values.

Products not found can be entered manually without losing the scanned barcode.

### Restaurant And Buffet

The existing restaurant mode is preserved as a local curated catalog for common
restaurant foods. The buffet tool supports incremental plate/item logging,
including the existing sushi-oriented categories:

- Nigiri
- Maki
- Tempura
- Gyoza
- Dessert
- Other

The user can adjust quantities and nutrition before creating the final meal.
The catalog is bundled JSON and can be updated in future app releases.

### Manual And Recent Entries

Manual entry supports:

- Name
- Portion
- Meal type
- Calories
- Protein
- Carbohydrates
- Fat
- Fiber
- Notes

Recent meals can be duplicated with the current date and selected meal type.

## History

History contains two primary modes:

- Calendar
- Week

Calendar mode shows daily completion relative to the active calorie goal and
opens a complete daily detail.

Week mode includes:

- Calories by day
- Average calories
- Days within target range
- Water compliance
- Meals logged
- Average protein, carbohydrates, and fat
- Macro distribution
- Weight evolution
- Meal list and deletion/editing

All calculations use local calendar boundaries and locale-aware dates.

## Weight

Weight entries contain date, kilograms, and creation date. The app provides:

- Quick entry from Today
- Complete log in Profile or History
- Weight trend chart
- Current, starting, target, and change values

Deleting or editing a log updates all derived charts immediately.

## Water

Water is stored per day in milliliters. Quick actions add common amounts and the
user can enter a custom amount. Daily and weekly views use a configurable water
goal, defaulting to 2500 ml.

## Recipes

Recipes support:

- Name
- Emoji
- Description
- Ingredients
- Instructions
- Detected or manually entered foods
- Calories, protein, carbohydrates, fat, and fiber per serving
- Number of servings
- Optional compressed photo

Creation paths:

1. Manual recipe with manual nutrition
2. Manual recipe with Gemini nutrition estimation
3. Import from URL

URL import first attempts Schema.org `Recipe` JSON-LD extraction. If structured
data is unavailable, sanitized page text is sent to Gemini to extract name,
ingredients, and servings. Gemini then estimates per-serving nutrition. The
result is always editable before saving.

A recipe can be logged as a meal, edited, deleted, or added to the weekly plan.

## Weekly Planner

The planner displays one week at a time and supports:

- Breakfast, lunch, dinner, and snack slots
- Adding a saved recipe
- Selecting servings
- Moving or deleting planned meals
- Daily planned calorie totals
- Previous and next week navigation

Plans reference recipes by stable SwiftData relationships. Recipe deletion must
either be blocked while referenced or leave a safe snapshot; it must never
produce broken planner rows.

## Shopping List

The shopping list combines:

- Ingredients derived from the current weekly plan
- Manually added items

Manual items are persistent and checkable. Derived ingredients remain traceable
to the plan and are recomputed when the plan changes. Identical normalized
ingredients are merged where practical, without pretending incompatible units
can be summed.

## Intermittent Fasting

Profile settings support:

- Enable/disable
- Protocol label, including 16:8
- Feeding window start
- Feeding window end

Today displays whether the user is fasting or inside the feeding window and the
time remaining until the next transition. Calculations handle windows crossing
midnight.

## Carb Cycling

Profile settings support:

- Enable/disable
- Training weekdays
- Training-day calorie goal
- Rest-day calorie goal

Today and History use the correct goal for each date. Manual macro targets may
also be provided for training and rest days in a future schema migration, but
are not required for version 1.

## Persistence Model

SwiftData entities:

- `UserProfile`
- `NutritionGoal`
- `Meal`
- `FoodItem`
- `DailyWater`
- `WeightEntry`
- `Recipe`
- `RecipeIngredient`
- `MealPlanEntry`
- `ShoppingItem`
- `AppPreferences`

Images are files in Application Support referenced by relative paths, not
embedded binary SwiftData attributes. Deleting a meal or recipe also deletes its
owned image when no other record references it.

The Gemini key is never stored in SwiftData, UserDefaults, logs, crash messages,
or exports. It is stored only in Keychain.

## Services

Focused service boundaries:

- `GeminiService`: image analysis, coach, recipe estimation, recipe URL fallback
- `OpenFoodFactsService`: product lookup and nutrient normalization
- `CameraService`: authorization and capture coordination
- `BarcodeScannerService`: AVFoundation barcode stream
- `ImageStore`: resizing, compression, persistence, cleanup
- `NutritionCalculator`: goals, totals, serving scaling, BMI, TDEE
- `FastingCalculator`: feeding/fasting state and countdown
- `ShoppingListBuilder`: derives and normalizes plan ingredients
- `KeychainStore`: Gemini key storage

Services use protocols so deterministic tests can replace network and camera
implementations.

## Privacy And Network Behavior

- No account or personal identifier is required.
- No analytics or advertising SDK.
- Gemini receives only the image/text and profile context needed for the action.
- Open Food Facts receives only the scanned barcode and normal HTTP metadata.
- The app includes a clear AI disclosure before first Gemini use.
- The user can delete all local data and the Keychain key from Profile.
- Export/import is outside version 1.

## Error Handling

Every async feature has explicit idle, loading, success, empty, and error states.
Network actions are cancellable. Retrying never creates duplicate meals or
recipes.

Before persistence:

- Validate numeric ranges.
- Normalize negative nutrients to zero.
- Reject non-finite values.
- Recalculate meal totals from edited food items.
- Require confirmation for destructive actions.

SwiftData failures are surfaced without discarding the user's current draft.

## Accessibility And UI Quality

- Dynamic Type supported without clipped controls.
- VoiceOver labels for progress charts, camera actions, barcode state, and
  nutrition rings.
- Minimum 44-point interactive targets.
- Do not communicate nutrition status by color alone.
- Respect Reduce Motion and Increase Contrast.
- Dark and light appearance supported.
- Stable card and chart dimensions prevent layout jumping during loading.

## Testing

Unit tests:

- Nutrition and TDEE calculations
- Serving scaling and meal totals
- Fasting windows, including midnight crossing
- Carb cycling target selection
- Shopping ingredient normalization
- Gemini JSON decoding and fallback error mapping
- Open Food Facts decoding
- Photo cleanup policy

SwiftData tests:

- CRUD for every entity
- Relationship deletion behavior
- Planner/recipe integrity
- Daily aggregation and weekly statistics

UI tests:

- First-launch profile setup
- Add manual meal
- Mock Gemini photo review and save
- Mock barcode review and save
- Water and weight logging
- Recipe creation and planner assignment
- Shopping item completion
- Data deletion

Build verification targets iOS 17 and the latest iOS 26 simulator.

## Release And SideStore

CalTracker is a separate app and bundle identifier from MoveLock. It will be
published as a second entry in:

`https://raw.githubusercontent.com/Blulyk/FocusGeofence-Source/main/source.json`

The release process produces an unsigned/ad-hoc IPA through GitHub Actions,
publishes it in `Blulyk/FocusGeofence-Source` releases, and updates both
`source.json` and `apps.json` without changing MoveLock history.

The SideStore metadata includes camera and photo privacy descriptions. No
background mode, Family Controls entitlement, Widget Extension, or additional
App ID is required for version 1.

## Explicit Non-Goals For Version 1

- Umbrel synchronization
- Accounts or multi-profile login
- iCloud or CloudKit
- HealthKit
- Apple Watch
- Widgets or Live Activities
- Social features
- Subscription or payment system
- Telemetry
