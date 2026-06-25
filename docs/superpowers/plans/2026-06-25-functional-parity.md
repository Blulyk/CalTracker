# CalTracker Functional Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore full CalorieAI workflow parity in the native iOS application without losing existing local data.

**Architecture:** SwiftData receives additive migration-safe fields and a buffet entity. Local image files are managed by a focused storage service, while editable value-type drafts isolate Gemini, barcode, restaurant and URL-import review from persistence.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, PhotosUI, AVFoundation, Security, URLSession, XCTest, GitHub Actions.

---

### Task 1: Persistent Media And Draft Domain

**Files:**
- Modify: `CalTracker/Models.swift`
- Create: `CalTracker/MediaStore.swift`
- Create: `CalTracker/AnalysisDraft.swift`
- Create: `CalTrackerTests/AnalysisDraftTests.swift`
- Modify: `CalTracker.xcodeproj/project.pbxproj`

- [ ] Write failing tests for draft totals, JSON round-trip and buffet local estimates.
- [ ] Compile tests and confirm missing types fail.
- [ ] Add migration-safe model properties and `BuffetSession`.
- [ ] Implement image save/load/delete and structured JSON helpers.
- [ ] Compile the app and tests.

### Task 2: Neutral Glass And Navigation

**Files:**
- Modify: `CalTracker/DesignSystem.swift`
- Modify: `CalTracker/RootView.swift`

- [ ] Remove full-card tint fills and retain accent borders/icons.
- [ ] Remove the floating duplicate add button.
- [ ] Add a persistent active-buffet status bar and one center registration action.
- [ ] Verify all four tabs render without colored overlays.

### Task 3: Home Parity

**Files:**
- Modify: `CalTracker/TodayView.swift`
- Create: `CalTracker/BuffetSessionView.swift`

- [ ] Add three small macro rings beneath the main balance.
- [ ] Rebuild Coach IA with the original violet gradient/loading treatment.
- [ ] Implement real buffet start, counting, categories, timer, estimation and save/discard.
- [ ] Replace `ProgressView` hydration with an animated gradient track and glow.
- [ ] Add meal photos, structured details and visible delete confirmation.

### Task 4: Editable Analysis And Restaurant Catalog

**Files:**
- Modify: `CalTracker/Services.swift`
- Modify: `CalTracker/LogView.swift`
- Create: `CalTracker/AnalysisReviewView.swift`
- Create: `CalTracker/RestaurantCatalog.swift`

- [ ] Preserve selected image and Gemini model/confidence in an analysis draft.
- [ ] Add editable food rows and recalculated totals.
- [ ] Implement repeat/rescan and save-one-meal behavior.
- [ ] Route barcode and restaurant results through the same review.
- [ ] Add searchable offline restaurant items for original supported chains.

### Task 5: Recipe Photos And URL Import

**Files:**
- Modify: `CalTracker/PlanView.swift`
- Create: `CalTracker/RecipeImportService.swift`
- Create: `CalTracker/RecipeImportView.swift`

- [ ] Add photo selection to recipe creation and persisted image rendering.
- [ ] Add change-photo and per-ingredient nutrition details.
- [ ] Fetch recipe URLs and normalize content with Gemini.
- [ ] Present imported data in the recipe editor before persistence.
- [ ] Keep manual recipe creation fully offline.

### Task 6: Planner And Shopping Parity

**Files:**
- Modify: `CalTracker/PlanView.swift`

- [ ] Add top calendar and URL-import controls matching the web layout.
- [ ] Build weekly navigation, meal-type selection, recipe search and servings.
- [ ] Generate deduplicated shopping suggestions from planned ingredients.
- [ ] Preserve manual shopping additions and checked state.

### Task 7: History And Profile Fixes

**Files:**
- Modify: `CalTracker/HistoryView.swift`
- Modify: `CalTracker/ProfileView.swift`

- [ ] Render meal photos and visible deletion in history.
- [ ] Add computed streak, hydration and buffet achievements.
- [ ] Display a masked Gemini key placeholder when configured.
- [ ] Prevent masked/empty input from overwriting Keychain.
- [ ] Remove excessive colored surface fills.

### Task 8: Full Audit And Distribution

**Files:**
- Modify: `.github/workflows/visual-qa.yml`
- Modify: `CalTracker.xcodeproj/project.pbxproj`
- Modify: `C:/Users/Blulyk/Documents/FocusGeofence-Source/source.json`
- Modify: `C:/Users/Blulyk/Documents/FocusGeofence-Source/apps.json`

- [ ] Compile the app and test target with Xcode 26.
- [ ] Capture every primary and modal workflow in Simulator.
- [ ] Compare the implementation against the deployed web feature inventory.
- [ ] Fix visual, migration and runtime findings.
- [ ] Build and validate the IPA, publish the release and update SideStore.
