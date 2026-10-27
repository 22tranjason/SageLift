# Empty-session cancellation and faster set entry

On Today, an active workout offers **Cancel Workout**. The confirmation buttons
are **Keep workout** and **Cancel empty workout**. Confirming resets only that
selected active session when its stored sets and raw draft have no entered
values. It remains planned, keeps its workout and retained set IDs, and receives
any existing approved equipment-plan migration. It does not create a completion,
skip the workout, advance the rotation or delete history. Cancellation works
across midnight for the same empty active session.

After cancellation, **Start Workout** starts the displayed recommendation.
If that recommendation differs from the cancelled workout, use **Choose Workout**
to select it explicitly. Cancelling does not change the recommendation history.
For Chest + Triceps the latest plan has five exercises: bench, incline dumbbell
press, flat-bench dumbbell fly, overhead dumbbell extension and cable pushdown.

Cancellation flushes pending writes, validates raw draft structure, refuses
entered/unknown/corrupt drafts and custom plans, and rechecks the stored record.
While it runs, the same session cannot accept edits, finish, start or be replaced.
Only a verified-empty draft is removed; failures reload the persisted lifecycle
state and can be retried. Publishing this feature does not cancel any session.

On an exercise, **Use last set** appears beside a set when actual completed
previous-session values can fill at least one blank field. It fills only blank
weight/reps fields, preserves partial input, and leaves values editable. Missing
history or missing values are not invented. The action uses the existing draft
save/retry path and does not complete a set or workout.
