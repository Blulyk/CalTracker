# CalTracker First Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, package, and publish the first native iOS 17 release of CalTracker with local nutrition tracking and optional Gemini/Open Food Facts integrations.

**Architecture:** A SwiftUI application uses SwiftData as the local source of truth, focused services for deterministic nutrition calculations and remote API calls, and five independent navigation tabs. The app remains useful offline; Gemini and barcode lookup enhance logging without owning user data.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Charts, PhotosUI, VisionKit/AVFoundation, Security, URLSession, XCTest, GitHub Actions.

---

## File Map

- `CalTracker/CalTrackerApp.swift`: app bootstrap and SwiftData container.
- `CalTracker/Models.swift`: persistent entities and nutrition value types.
- `CalTracker/Services.swift`: goals, Keychain, Gemini, Open Food Facts, image handling.
- `CalTracker/DesignSystem.swift`: brand tokens, reusable glass surfaces, progress UI.
- `CalTracker/OnboardingView.swift`: local profile creation.
- `CalTracker/RootView.swift`: five-tab navigation and shared add-meal presentation.
- `CalTracker/TodayView.swift`: daily dashboard, meals, water, fasting.
- `CalTracker/LogView.swift`: manual, photo, barcode, recent and recipe logging.
- `CalTracker/HistoryView.swift`: daily history, weight and trend charts.
- `CalTracker/PlanView.swift`: recipes, weekly meal plan and shopping list.
- `CalTracker/ProfileView.swift`: profile, calculated goals, integrations and privacy.
- `CalTrackerTests/CalTrackerTests.swift`: deterministic calculation and parsing tests.
- `CalTracker.xcodeproj/project.pbxproj`: iOS app and test targets.
- `.github/workflows/ios-build.yml`: simulator build and tests.
- `.github/workflows/ipa-unsigned.yml`: device build and SideStore-compatible IPA.

### Task 1: Project Foundation And Domain Model

- [ ] Create the Xcode project, Info.plist, asset catalog and SwiftData app entry.
- [ ] Add persistent models for profile, foods, meals, water, weight, recipes, plans and shopping.
- [ ] Add deterministic goal calculation and unit tests for lose, maintain and gain scenarios.
- [ ] Run the tests on GitHub's iOS Simulator and commit the foundation.

### Task 2: Local Profile And Design System

- [ ] Build required onboarding with validation and calculated calorie/macronutrient preview.
- [ ] Store the local profile in SwiftData and the Gemini key in Keychain.
- [ ] Implement blue/orange semantic tokens, material surfaces and iOS 26 glass availability paths.
- [ ] Build light/dark interfaces with Dynamic Type and accessibility labels.

### Task 3: Daily Tracking

- [ ] Build the Today dashboard from real SwiftData queries.
- [ ] Add meal grouping, calorie/macronutrient totals, water increments, fasting state and weight entry.
- [ ] Ensure date changes read the correct local records and never seed fake analytics.
- [ ] Add empty, loading and destructive-confirmation states.

### Task 4: Food Logging And Integrations

- [ ] Build a complete manual food editor with typed nutrient validation.
- [ ] Add photo selection and Gemini analysis with structured JSON decoding and editable results.
- [ ] Add camera barcode scanning and Open Food Facts lookup with manual fallback.
- [ ] Add recents and recipe logging while preserving offline operation.

### Task 5: History, Recipes, Planning And Shopping

- [ ] Build weekly history, calorie/macronutrient summaries and weight charts.
- [ ] Add recipe creation, editing, serving calculations and meal logging.
- [ ] Add weekly meal-plan entries and a generated/editable shopping checklist.
- [ ] Persist every change locally and test aggregate calculations.

### Task 6: Identity, Verification And Distribution

- [ ] Create the CalTracker app icon and verify all required asset slots.
- [ ] Run clean simulator and device builds with warnings treated as actionable failures.
- [ ] Package an unsigned/ad-hoc IPA with a valid Payload layout and linted Info.plist.
- [ ] Publish source and IPA on GitHub, then append CalTracker to the existing SideStore source without altering MoveLock entries.
- [ ] Verify the raw source JSON, icon URLs, download URL and IPA archive over HTTPS.

## Acceptance Checks

- [ ] First launch reaches local onboarding and never requests an account.
- [ ] Profile changes recalculate goals locally and survive relaunch.
- [ ] Manual meals, water, weight, recipes, plans and shopping survive relaunch.
- [ ] Photo and barcode paths fail clearly when offline or unconfigured.
- [ ] No sample nutrition records are inserted into production storage.
- [ ] The app runs on iOS 17 and adopts native Liquid Glass only when available.
- [ ] GitHub Actions produces an installable `.ipa`.
- [ ] SideStore can refresh the source and see CalTracker as an independent app.
