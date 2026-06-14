# CalSnap — AI Calorie Counter for iPhone

Snap a photo or video of your meal and let AI recognize the food and estimate
calories & macros. Track your daily intake, connect Apple Health to factor in
calories burned, and see your net for the day — all in a clean, themed UI with
full dark / light mode.

## Features

| Feature | Description |
|--------|-------------|
| 📸 Snap a meal | Take a **photo** or short **video**; AI identifies every food item |
| 🤖 Claude Vision | Accurate recognition + calorie/macro estimation via the Claude API |
| 🎥 Video analysis | Pan across the table — frames are sampled and analyzed together |
| 🔥 Apple Health | Reads active + resting energy burned for an accurate daily **net** |
| 🍽️ Daily dashboard | Calorie ring, remaining budget, protein / carbs / fat progress |
| 📖 Diary | Every meal, grouped by day, with thumbnails and totals |
| 📊 Insights | 7-day calorie chart vs. goal + weekly macro split (Swift Charts) |
| 🎯 Smart goals | Mifflin–St Jeor TDEE with activity & goal, or set a manual target |
| 🌗 Theme | Custom CalSnap design system, System / Light / Dark |
| ✏️ Editable results | Tweak any AI estimate before saving |
| 🔌 Offline fallback | Works without a key using rough estimates you can adjust |

## Architecture

```
CalSnap/
├── App/
│   ├── CalSnapApp.swift        # @main, SwiftData container, theme
│   └── RootView.swift          # Onboarding gate + custom floating tab bar
├── Models/
│   ├── FoodEntry.swift         # SwiftData model + FoodItem + MealType
│   └── UserProfile.swift       # TDEE/goal math, theme mode enums
├── Theme/
│   ├── Theme.swift             # Palette, gradients, typography, metrics
│   └── ThemeModifiers.swift    # Card surface + button styles
├── Services/
│   ├── FoodVisionService.swift # Claude Vision API (photo + video frames)
│   ├── OfflineEstimator.swift  # Keyword fallback when no API key
│   ├── HealthKitService.swift  # Read energy burned, write meals
│   ├── KeychainService.swift   # Secure API key storage
│   └── Utilities.swift         # Image resize, date & number helpers, haptics
├── ViewModels/
│   ├── AppState.swift          # Observable app state (profile, theme, key)
│   └── CaptureViewModel.swift  # Capture → analyze → review flow
└── Views/
    ├── Onboarding/             # Paged welcome + quick profile
    ├── Home/                   # Daily dashboard (calorie ring, macros)
    ├── Capture/                # Camera/library pickers, analysis, review
    ├── Diary/                  # History + meal detail
    ├── Insights/               # Charts
    ├── Settings/               # Profile, theme, Health, API key
    └── Components/             # CalorieRing, MacroBar, shared UI
```

## Tech

- **SwiftUI** (iOS 17) with the `@Observable` macro
- **SwiftData** for local persistence
- **Claude Vision API** (Anthropic) for food recognition
- **HealthKit** for energy burned & dietary writes
- **Swift Charts** for insights
- **AVFoundation** for video frame sampling

## Build

### Prerequisites
- macOS 14+, Xcode 15+, iOS 17+ target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Generate & run
```bash
cd CalSnap
xcodegen generate
open CalSnap.xcodeproj
```
1. Select your **Team** under Signing & Capabilities (HealthKit needs a signed build on device).
2. Run on a device (camera + Health require real hardware).

## Connecting Claude

1. Create an API key at [console.anthropic.com](https://console.anthropic.com).
2. In the app: **Settings → Claude API Key** → paste and save.
3. The key is stored in the device Keychain and sent only to Anthropic.

The vision model is set in `FoodVisionService.model` (defaults to
`claude-sonnet-4-6`); switch to a heavier model for maximum accuracy.

## Notes

- The bundled app icon is a generated placeholder — drop in your own 1024² in
  `Assets.xcassets/AppIcon.appiconset`.
- Without an API key the app still works using a coarse on-device estimate that
  you can edit before saving.
