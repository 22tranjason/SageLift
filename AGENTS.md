# SageLift agent guidelines

## Before editing

- Inspect the repository, relevant feature, and existing conventions before making changes.
- Keep each change small, scoped to the current milestone, and avoid overengineering.
- Never modify unrelated files.
- Ask before making destructive changes or changing public APIs.
- Clearly report every changed file when work is complete.

## Architecture and dependencies

- Never add packages without approval.
- Never change the architecture without approval.
- Keep domain code independent of Flutter, Hive, and other storage or infrastructure frameworks.
- Keep business logic out of widgets; widgets should focus on presentation and interaction.
- Preserve the offline-first behaviour of the application.

## Code quality

- Prefer immutable classes and explicit types.
- Add or update tests for meaningful logic.
- Run formatting, static analysis, and tests after implementation.
- Report validation results and any limitations clearly.
