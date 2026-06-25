# Web-Inspired Apple UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign every primary CalTracker screen to retain the CalorieAI web application's character while using native Apple interaction and visual patterns.

**Architecture:** Shared visual primitives and date aggregation helpers provide one source of truth for colors, cards, date strips and daily nutrition state. Each tab remains a focused SwiftUI screen backed by the existing SwiftData models and services.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Charts, PhotosUI, AVFoundation, iOS 17 materials, iOS 26 Liquid Glass, GitHub Actions.

---

### Task 1: Testable UI Data Helpers

**Files:**
- Create: `CalTracker/DailySummary.swift`
- Create: `CalTrackerTests/DailySummaryTests.swift`
- Modify: `CalTracker.xcodeproj/project.pbxproj`

- [ ] Add failing tests for selected-day meal totals, water totals, exceeded-target state and week date generation.
- [ ] Run the iOS test target and verify the helpers are missing.
- [ ] Implement `DailySummary` and `Calendar.week(containing:)`.
- [ ] Run the tests and verify all aggregation cases pass.

### Task 2: Shared Visual System And App Shell

**Files:**
- Modify: `CalTracker/DesignSystem.swift`
- Modify: `CalTracker/RootView.swift`
- Modify: `CalTracker/CalTrackerApp.swift`

- [ ] Add semantic canvas, surface, border and nutrition colors for dark and light appearance.
- [ ] Add reusable `AppSurface`, `EyebrowLabel`, `IconBadge`, `MetricChip`, `PrimaryActionButton` and `WeekStrip`.
- [ ] Replace five equal tabs with Inicio, Recetas, central Registrar action, Historial and Perfil.
- [ ] Preserve independent navigation stacks and native sheet presentation.

### Task 3: Inicio Redesign

**Files:**
- Modify: `CalTracker/TodayView.swift`

- [ ] Add greeting, profile monogram and web-inspired week strip.
- [ ] Build the large calorie headline and daily balance ring card.
- [ ] Add macro footer, streak, Gemini coach, buffet, hydration and weight cards.
- [ ] Restyle real meal groups and the empty state.
- [ ] Check Dynamic Type and VoiceOver descriptions for metrics and controls.

### Task 4: Registro Redesign

**Files:**
- Modify: `CalTracker/LogView.swift`

- [ ] Present Registro as a native full-screen sheet from the center action.
- [ ] Add meal-type and input-source segmented controls.
- [ ] Build the large photo target, gallery picker, scanner action, recipe shortcut and recent list.
- [ ] Restyle Gemini and Open Food Facts result editing while preserving real persistence.
- [ ] Retain explicit loading and error states.

### Task 5: Recetas, Semana And Compra

**Files:**
- Modify: `CalTracker/PlanView.swift`

- [ ] Make Recetas the default section with search and strong create action.
- [ ] Replace plain list rows with visual recipe cards and macro chips.
- [ ] Restyle weekly plan cards and shopping checklist.
- [ ] Keep recipe detail, logging and deletion behavior intact.

### Task 6: Historial Redesign

**Files:**
- Modify: `CalTracker/HistoryView.swift`

- [ ] Add month navigation and calendar/week segmented mode.
- [ ] Build a native month grid with nutrition, exceeded and hydration markers.
- [ ] Add selected-day calorie progress and hydration surfaces.
- [ ] Retain real meal detail and Swift Charts weight trend.

### Task 7: Perfil Redesign

**Files:**
- Modify: `CalTracker/ProfileView.swift`

- [ ] Replace `Form` with a scroll dashboard and designed editable surfaces.
- [ ] Add goal tiles, activity rows and calculated metric cards.
- [ ] Restyle Gemini, fasting, privacy and destructive actions.
- [ ] Preserve Keychain behavior, local profile editing and data deletion.

### Task 8: Build And Visual Verification

**Files:**
- Modify when required by findings: `CalTracker/*.swift`
- Modify: `.github/workflows/ios-build.yml`

- [ ] Run simulator build and tests with Xcode 26.
- [ ] Render onboarding and every primary tab in an iOS simulator.
- [ ] Capture screenshots and inspect clipping, contrast, empty states and tab behavior.
- [ ] Fix every visual or runtime issue found and repeat verification.

### Task 9: Distribution

**Files:**
- Modify: `CalTracker.xcodeproj/project.pbxproj`
- Modify: `C:/Users/Blulyk/Documents/FocusGeofence-Source/source.json`
- Modify: `C:/Users/Blulyk/Documents/FocusGeofence-Source/apps.json`

- [ ] Increment app version and build.
- [ ] Produce and validate a new IPA with GitHub Actions.
- [ ] Publish the release and update both SideStore manifests.
- [ ] Verify remote JSON, icon and IPA URLs.
