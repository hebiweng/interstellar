# iOS Offline Global Locations Design

## Goal

Keep the existing Apple map, search field, and selection sheet while making global city search and city-backed map selection work when public MapKit geocoding returns only mainland-China data or no result.

## Product Contract

- There is one search field and one result list; no second offline-search UI is introduced.
- Apple current location, Apple search, and Apple map taps remain the only user-facing location entry mechanisms.
- Apple results remain available, while verified offline city results are merged into the same list so an exact global city is not hidden behind irrelevant regional Apple matches.
- If Apple reverse geocoding fails for a map tap, the app selects a nearby real GeoNames city and uses that city's coordinates and IANA timezone. It never applies a nearby city's timezone to an arbitrary coordinate.
- The app never substitutes `TimeZone.current` for an unresolved selected coordinate.
- An unmatched ocean point, an ambiguous timezone boundary, corrupt data, or an invalid IANA timezone fails explicitly and leaves Done disabled.
- No location query or coordinate is sent to Relay or another third party by the offline fallback.

## Data Sources and Licensing

- GeoNames `cities500-2026-07-19.zip` supplies populated-place names, aliases, coordinates, population, country/admin hierarchy, and timezone hints. License: CC BY 4.0.
- Timezone Boundary Builder `timezones-2026b.geojson.zip` is build-only input used to backfill the one GeoNames row without a timezone. It is not bundled in the app. Output license: ODbL 1.0; underlying OpenStreetMap attribution is preserved.
- IANA timezone identifiers are validated against Foundation `TimeZone` at runtime.
- Dataset versions, SHA-256 hashes, and attributions remain recorded in the existing vendor READMEs and lock manifest. A concise runtime attribution resource is added to the iOS bundle.

## Build-Time Artifact

`scripts/build-ios-offline-locations.py` validates the locked source hashes and emits `ios/App/Resources/OfflineLocations.sqlite3` deterministically.

The database contains:

- `places`: all 234,994 GeoNames populated places with display fields, coordinates, population, and a compact timezone index.
- `place_search`: a contentless FTS5 index over primary, ASCII, and alternate names for prefix search.
- `timezones`: 394 deduplicated IANA identifiers referenced by compact integer indexes.
- `metadata`: schema version, source versions, hashes, licenses, and generated record counts.

The checked-in database is the runtime resource. The app does not parse ZIP or full GeoJSON files at launch. The generator is the only supported way to update it.

## iOS Architecture

`OfflineLocationStore` owns the read-only SQLite connection and exposes:

```swift
func search(query: String, limit: Int) throws -> [OfflinePlace]
func resolve(latitude: Double, longitude: Double) throws -> OfflineCoordinateResolution?
```

Search uses prefix matching and population ranking. Coordinate resolution finds a nearby real city within a bounded radius and returns that city's name, coordinate, and verified timezone.

`LocationSearchService` continues to own MapKit. It asynchronously queries the offline store alongside `MKLocalSearchCompleter`, publishes a single typed result collection, and resolves either an Apple completion or an offline place into the existing `LocationSelection` model.

For a map tap, `LocationSearchService.resolve(_ coordinate:)` keeps Apple reverse geocoding as the first choice. Offline success snaps the selection to a nearby known city rather than guessing the timezone for the arbitrary tapped coordinate.

## Failure and Performance Boundaries

- The database opens read-only from `Bundle.main`; missing or invalid schema disables only offline fallback and surfaces the existing localized unavailable state.
- Search is debounced and cancellable. The UI never scans the source dataset in memory.
- A missing database disables only offline fallback and surfaces the existing localized unavailable state.
- A tap farther than 150 km from a known city remains unavailable rather than receiving a guessed timezone.
- Unit fixtures cover multilingual aliases, compact timezone indexes, build-time antimeridian backfill, nearest-city selection, and unmatched ocean points.

## Release Scope

- Increment iOS build number from 11 to 12.
- Run the location unit tests, iOS unit suite, project gates, iPhone 12 mini global search/tap smoke, and a generic iPhoneOS build.
- Produce a Build 12 App Store candidate Archive, but do not upload it.
- Update product backlog, release readiness, and agent handoff with the implementation and evidence.
