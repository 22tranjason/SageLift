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
