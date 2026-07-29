# SageLift architecture

## Approach

SageLift uses feature-first Clean Architecture. Each feature may contain three layers:

```text
features/<feature>/
  data/
  domain/
  presentation/
```

Dependencies point inward:

```text
presentation -> domain <- data
```

The domain layer must not depend on data or presentation.

## Layer responsibilities

- **Domain** contains entities, value objects, use cases, and repository interfaces. It remains independent of Flutter, Hive, and other infrastructure packages.
- **Data** contains Hive implementations, persistence models, data sources, and repository implementations.
- **Presentation** contains feature widgets, view state, and presentation-facing controllers.

Repository interfaces belong in `domain`; their Hive-backed implementations and persistence models belong in `data`.

Riverpod providers belong near the layer they expose. Providers that expose a repository implementation belong near that data boundary, while presentation state belongs with the feature presentation layer.

GoRouter handles app navigation from the application routing layer.

## Persistence and offline use

SageLift is offline first. Locally stored data must remain usable without a network connection.

Domain models must remain free of Hive annotations and Flutter imports. Persistence models are separate from domain models, and mapping between them must be explicit. This keeps storage details replaceable and makes migrations easier to reason about.

Store source facts, not needless derivations. For example, body weight and height may be persisted, while BMI should be calculated when needed rather than stored.
