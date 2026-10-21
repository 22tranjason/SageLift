# Updating cached SageLift installations

The old Update now action flushed pending workout drafts and changed the document
query, but index.html still requested unversioned flutter_bootstrap.js, whose
loader requested unversioned main.dart.js. HTTP or legacy service-worker caches
could therefore keep executing the previous app while version.json correctly
reported a new deployment, producing a repeated update prompt.

The index now reads version.json with both a cache-busting query (avoiding known
legacy worker resource keys) and no-store HTTP semantics. A four-second timeout
allows offline fallback. It loads a release-specific bootstrap URL. The custom
Flutter bootstrap propagates that release ID to JavaScript and Wasm entrypoint
URLs. It uses Flutter's existing loader and documented bootstrap template tokens.
No CacheStorage entries, service-worker registrations, localStorage values or
IndexedDB records are removed. Assets unrelated to this release remain untouched.
The only new local metadata key, sagelift.loaded-build.v1, records the release
once its entrypoint loads and enables offline fallback; it contains no user data.
Pending drafts still flush through the existing Update now controller before
navigation. The same origin, base path and route are retained.

Validation includes Node built-in regression tests (run in release CI), the full
Flutter suite, analysis and a release build. A local Chromium test reproduced the
old stale-bootstrap update with long-lived HTTP cache headers, then loaded two
successive corrected releases while retaining a localStorage history sentinel,
an IndexedDB draft and an unrelated CacheStorage resource. Offline selection of
the requested/last loaded release is covered by the Node tests. Physical iPhone
offline behavior still requires device verification.

Reference: https://docs.flutter.dev/platform-integration/web/initialization
