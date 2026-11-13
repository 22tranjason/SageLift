# SageLift

SageLift is an offline-first, long-term personal fitness progression system. This repository intentionally contains only the production foundation: no workout flows, tracking screens, or product feature UI have been built.

## Why this stack

- **Flutter + PWA** — a single typed codebase for Android, iOS, desktop, and web. The web runner enables installable PWA behaviour.
- **Material 3** — accessible platform-adaptive components and one coherent light/dark design system.
- **Riverpod** — testable dependency injection and predictable asynchronous state without widget-tree coupling.
- **GoRouter** — declarative, named routes that can later support deep links and web URLs.
- **Hive** — lightweight browser-compatible persistence for the offline-first release. Application code uses `KeyValueStore`, keeping a future migration to Drift/SQLite or encrypted storage contained.
- **flutter_lints** — an opinionated baseline strengthened with rules that make public APIs and asynchronous behavior explicit.

## Architecture

The project uses Clean Architecture inside a feature-first layout. Dependencies point inward:

`presentation -> domain <- data`

`core` contains cross-cutting technical abstractions. `shared` contains reusable presentation primitives only once two or more features need them. A feature must not import another feature's data or presentation layer; share a domain contract or elevate a truly shared abstraction into `core`.

```
lib/
  app/                         # composition root: app, router, Material themes
  core/
    storage/                   # persistence interface and Hive implementation
  features/
    settings/
      data/                    # repository implementations and DTOs
      domain/                  # entities, value objects, contracts, use cases
      presentation/            # Riverpod controllers and feature-specific UI
  shared/
    presentation/              # cross-feature UI (currently bootstrap only)
  main.dart                    # startup and dependency wiring
test/
  features/                    # tests mirror production feature paths
```

The lone route is a responsive, intentionally minimal bootstrap page. It exists only to prove the application starts; no product UI has been designed or implemented.

## Adding a future feature

For workouts, measurements, habits, nutrition, photos, records, achievements, challenges, statistics, sync, or Home Assistant integration:

1. Create `lib/features/<feature>/{domain,data,presentation}`.
2. Start with domain entities, value objects, repository interfaces, and focused use cases. Keep them Flutter- and Hive-free.
3. Implement data models and repositories in `data`, using `core/storage` only through interfaces.
4. Add Riverpod providers/controllers and small responsive widgets in `presentation`.
5. Add a named `GoRoute` in `lib/app/router/app_router.dart`; avoid raw path strings outside the routing layer.
6. Add unit tests under `test/features/<feature>` before widget and integration tests.

Use `LayoutBuilder`, max-width constraints, and Material 3 adaptive controls for desktop/mobile layouts. Source visual values from `ThemeData` rather than hard-coding colors, text styles, or spacing in features.

## Local setup

After Flutter and Git are installed and on your `PATH`:

```bash
flutter create . --platforms=android,ios,web,windows,macos,linux
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
git init
git add .
git commit -m "chore: initialize SageLift foundation"
```

`flutter create` preserves the existing source, lint rules, tests, README, and `.gitignore` while adding standard platform runners and PWA assets. Review the generated diff before committing.

## Recommended decisions before feature work

1. Define a domain glossary plus immutable IDs, time-zone handling, units, and deletion/retention rules.
2. Decide whether sensitive data requires encryption at rest from day one; photos and health-adjacent data normally warrant it.
3. Establish a versioned local-data migration policy before persisting workout records.
4. Choose a cloud-sync conflict strategy before accounts exist; an append-only event log fits training history well.
5. Define privacy, export/delete, backup, and accessibility expectations before collecting personal data.
6. Add CI to run formatting, analysis, tests, and a web build when a remote repository is created.

## GitHub Pages

The deployed web app is available at `https://22tranjason.github.io/SageLift/` after the GitHub Pages workflow has successfully run from `main`. It uses browser-local storage, so it works without a backend or cloud database.

Safari website-data clearing can erase SageLift data. Each browser and device keeps a separate local copy of that data.

## Beginner workouts and progress picker

Use **Switch to Nhi’s workouts** on Today for a gentle repeatable full-body session.
The choice is remembered on that browser. Nhi can use the app on her own phone;
there is no automatic cross-device sync. Her draft and completion records use a
separate settings key and are included in the existing backup/export. Jason's
workout history and progression are unchanged. The Progress picker defaults to
exercises with completed logged sets; **Show all exercises** reveals the catalogue
without deleting older records.

CI uses Flutter 3.44.9 to keep the existing Material API and validation reproducible.

## Local food log

Jason's Today screen opens **Food log**. Search favourites/recent foods, tap an
item, and enter servings or grams (when a reference weight is known). Tap a
logged item to edit its portion; deletion asks for confirmation. Choose an older
calendar date to review or correct a previous day.

**Create custom food or recipe** saves the whole meal for reuse, even when the
next portion dialog is cancelled. For an estimated lunch, use a name such as
`Chicken rice lunch (estimate)`, a serving such as `1 lunchbox`, and estimated
calories/protein. Optional weight enables scaling by grams next time. No recipe
builder, network food database, account, AI API or chat-to-app sync is involved.

The daily total includes food-log entries only. Existing manual daily protein
records remain untouched and are not added to this total, preventing duplicate
counting. The diary uses the versioned `jason.foodLog.v1` settings key, included
in the existing backup/export. Clearing browser data can erase it; different
phones/browsers do not sync.

Seed values are exact variants checked on official product pages in November
2026: UP&GO Protein Energize Choc Hit 250 mL (201 kcal, 17.9 g protein) and YoPRO
vanilla 160 g pot (91 kcal, 15.2 g protein). Current packaging takes precedence:
https://upandgo.com.au/products/protein-energize and
https://www.yopro.com.au/products/pots/pot-vanilla/.

## Optional Google Drive backup sync

The web app can upload one **private** `SageLift - Latest Backup.json` file to
your Google Drive. It uses the same full, versioned JSON as the local backup
feature, except it removes `sagelift.drive.*` app-connection metadata. This
includes all profiles; only connect an account you trust. **No data is sent to
GitHub**, and Google access tokens are never written into SageLift storage.

First-time setup (one-time Google Cloud configuration):

1. In [Google Cloud Console](https://console.cloud.google.com/), create/select
   a project and **enable the Google Drive API**.
2. Configure the OAuth consent screen / Google Auth Platform, and add your
   Google account as a test user if the application is in testing mode.
3. Create an **OAuth 2.0 Client ID** of type **Web application**, with
   **Authorized JavaScript origin** `https://22tranjason.github.io`.
   You do not need to put a client secret or access token in GitHub or SageLift.
4. In SageLift, go to **Settings → Private Google Drive sync**, paste the
   `*.apps.googleusercontent.com` client ID, and tap **Connect & Sync now**.
   Choose your account and grant Google Drive access to files created by this app.

The app requests only Google's `drive.file` scope, so it cannot browse other
Google Drive files. It reuses one backup file instead of creating a new file
every few minutes. By default, after a successful first upload, it checks for
changes every three minutes **while the app is open and authorised** and also
when you return to the app. Unchanged data is skipped. If you close/reload the
app or the short-lived token expires, tap **Connect & Sync now** to authorise
again; Google's browser token model intentionally cannot refresh without a
user interaction. The app does not perform background sync when closed.

**Local SageLift logging, ordinary backup and restore continue to work without
Drive.** Disconnecting only removes this browser's connection information; it
does not remove your local records or the already uploaded Drive file.
