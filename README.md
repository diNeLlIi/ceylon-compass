# Wander Lanka

A weather-aware travel planning application for Sri Lanka, built with SwiftUI.

Sri Lanka's climate varies sharply by district — settled weather on the south
coast can coincide with sustained rain in the central highlands. Wander Lanka
integrates forecast data directly into itinerary planning rather than treating
it as separate reference information.

**Tagline:** Plan around the rain, not into it.

Individual coursework for iOS Application Development, BSc (Hons) Computing,
batch BSCCOMP25.1P, National Institute of Business Management.

---

## Features

- **Explore** — browse Sri Lankan destinations with search, category and
  province filtering, each card showing live forecast conditions
- **Destination detail** — seven-day forecast, charted temperature and rainfall
  trends, UV index, and the best weather window identified automatically
- **Compare** — two or three destinations side by side, aligned day by day, with
  a draggable day selector and best-window highlighting
- **Plan a trip** — corridor-filtered stops between origin and destination, plus
  points of interest discovered along the route from OpenStreetMap
- **Itinerary** — day-grouped stops with drag-to-reorder, travel legs, and
  conflict detection for storms, double-booked dates and infeasible travel times
- **Map** — weather-coded pins, route overlay, discovered-place pins, standard
  and satellite rendering, and geofenced arrival alerts
- **Memories** — rate and photograph visited stops, with on-device Vision
  analysis filling notes from signage and suggesting which stop a photo matches
- **Widgets** — next stop and forecast on the Home Screen and Lock Screen
- **Siri Shortcuts** — parameterised intents for forecast lookup, itinerary
  display and adding a destination
- **iPad** — split-view navigation and adaptive grids, not a scaled iPhone layout

---

## Requirements

- Xcode 16 or later (the test suite uses Swift Testing, not XCTest)
- iOS 17.0 or later
- A free Apple ID — no paid Apple Developer Program membership is needed

No CocoaPods, Carthage or manual framework installation. Dependencies resolve
through Swift Package Manager when the project is first opened.

---

## Running the project

### 1. Open


Wait for Swift Package Manager to finish resolving dependencies — progress shows
in the Xcode status bar. First resolution can take several minutes.

### 2. Firebase configuration

The app requires `GoogleService-Info.plist` at `celon-compass/GoogleService-Info.plist`,
included as a member of the app target. **The app will not launch without it.**

If the file is absent from your copy, it is supplied in the submission archive.

### 3. Signing

Select the project in the navigator, then for **both** targets — the app and the
widget extension:

- Open the Signing & Capabilities tab
- Set Team to your own Apple ID (add one via Xcode → Settings → Accounts)
- Change the bundle identifier if Xcode reports a conflict

The App Group capability is already declared in the entitlements for both
targets and should not need changing.

### 4. Build and run

Select an iPhone simulator and press Cmd+R.

---

## Backend access

**No setup or credentials are required.** The app signs in anonymously to
Firebase on first launch and is immediately usable. Creating an email account is
optional and only enables cross-device synchronisation.

Open-Meteo and the Overpass API require no key and no configuration.

---

## Running the tests

In Xcode: **Cmd+U**

From the command line:


Tests use the Swift Testing framework. Coverage includes distance calculation,
best-window selection, conflict rules and forecast response parsing.

---

## Exercising device features in the Simulator

Location, geofencing and image analysis need setup before they can be
demonstrated in a fresh simulator.

### Location

**Features → Location → Custom Location**

| Place | Latitude | Longitude |
|---|---|---|
| Colombo | 6.9271 | 79.8612 |
| Galle Fort | 6.0257 | 80.2170 |
| Mirissa | 5.9483 | 80.4716 |
| Ella | 6.8667 | 81.0463 |
| Sigiriya | 7.9570 | 80.7603 |

### Geofenced arrival alerts

Geofencing requires **Always** location authorisation. When In Use will not
deliver background region events.

1. Create a trip with at least one stop
2. Grant Always authorisation (Settings → Wander Lanka → Location)
3. Set the simulator location well away from the stop — Colombo works
4. Wait about ten seconds
5. Set the location to the stop's coordinates
6. Allow up to thirty seconds for the notification

Simulator geofencing is intermittent by nature. If nothing fires, move further
away and re-enter before assuming a fault.

### Memories and Vision

The image analysis pipelines need photographs in the simulator's library. Drag
JPEG files from Finder onto the simulator window and they appear in Photos.

Include at least one photograph containing clear signage or an information
plaque to demonstrate text recognition, and one or more recognisable landmark
photographs to demonstrate place matching.

Then open a past trip from My Trips, choose Complete trip, attach a photograph,
and view the result in the Memories tab.

### Widgets

Run the app once so data exists, then on the simulator Home Screen long-press,
choose Edit, then Add Widget, and search for Wander Lanka. Add the small, medium
and Lock Screen variants.

### Siri Shortcuts

Open the Shortcuts app in the simulator and search for the app name. Shortcuts
exercises the same intent resolution as Siri and is more reliable in a simulator.

### iPad

Select an iPad Pro 11-inch or 13-inch simulator. Layout adapts by horizontal
size class, so Split View at half width is also worth trying.

---

## Architecture


**Pattern.** MVVM with protocol-oriented dependency injection. Every service sits
behind a protocol so view models depend on abstractions rather than concrete
types. This is what allows the test suite to run without network access, and it
is what allowed the routing implementation to be replaced during development
without touching a single call site.

**Persistence.** Core Data is the source of truth; Firebase Firestore is a
synchronisation layer above it. The app is fully functional offline, and
synchronisation is an enhancement rather than a dependency.

**Pure logic separated.** Code in `Logic/` has no dependency on Core Data,
networking or the user interface, making it directly unit-testable and reusable
across several screens.

**Derived state.** Trip lifecycle — upcoming, active, history — is computed from
dates at the point of use rather than stored, because a stored status becomes
stale when the condition that set it changes with the passage of time rather
than with a user action.

---

## External services

| Service | Purpose | Key required |
|---|---|---|
| Open-Meteo | Seven-day forecasts by coordinate | No |
| Firebase Firestore | Destination catalogue, user data sync | Via Firebase Auth |
| Overpass (OpenStreetMap) | Points of interest along a route | No |

Point-of-interest data is © OpenStreetMap contributors, available under the
[Open Database License](https://opendatacommons.org/licenses/odbl/).

---

## Known limitations

**Road distances are estimates.** Turn-by-turn routing via MKDirections requires
a paid Apple Developer Program membership, which the project's zero-cost
constraint rules out. Distances use great-circle calculation with a tuned road
factor and are documented as estimates in code.

**Photographs do not synchronise.** Firebase removed Cloud Storage from the free
Spark plan in February 2026. Memory metadata — ratings, notes, recognised text,
coordinates — synchronises in full; images remain on the originating device,
with a designed placeholder shown elsewhere.

**Forecasts are limited to sixteen days.** This is the provider's maximum. Trips
scheduled beyond that horizon cannot display per-day conditions.

**Not verified on physical hardware.** Development was simulator-only, so GPS
accuracy, region entry latency and background wake behaviour under real
conditions are untested.

---

## Troubleshooting

**Crashes immediately on launch** — `GoogleService-Info.plist` is missing or not
a member of the app target. See step 2 above.

**"Failed to register bundle identifier"** — change the bundle identifier to
something unique under your own team.

**Widget shows no data** — confirm the App Group capability is present on both
the app target and the widget extension with the same identifier, and that the
app has been run at least once.

**Geofence never fires** — authorisation must be Always rather than When In Use.
See the geofencing section above.

**Explore is empty** — the catalogue seeds from Firestore on first launch, which
needs network access. Check the Firebase configuration file and your connection.

---

## Licence

Submitted as individual coursework for BSCCOMP25.1P. Not licensed for reuse.

