# Four-day strength and hypertrophy split

Suggested week: Tuesday chest + triceps, Wednesday back + biceps, Thursday rest,
Friday shoulders + traps, Saturday legs + calves, Sunday and Monday rest.
This is guidance, with four sessions and three rest days. The existing app rotates
by completed sessions. Rest or missed days do not advance it. Choose Workout
remains available on any day, including Thursday, without changing this schedule.

Working sets below exclude warm-ups. Allow 8–10 minutes of easy walking, joint
mobility and 2–4 gradual ramp-up sets for the first lift, plus light preparation
sets before the next compound lift. Weekdays target 50–60 minutes including
warm-up; Saturday targets 65–75 minutes. Rest periods are between working sets.

| Session | Exercise | Sets × reps | Rest |
|---|---|---|---|
| Chest + Triceps | Barbell Bench Press | 3 × 4–6 | 180 sec |
| | Incline Dumbbell Press | 3 × 8–10 | 120 sec |
| | Cable Chest Fly | 3 × 10–15 | 75 sec |
| | Overhead Triceps Extension (dumbbell) | 3 × 10–15 | 75 sec |
| Back + Biceps | Barbell Bent-Over Row | 3 × 6–8 | 150–180 sec |
| | Cable Lat Pulldown | 3 × 8–12 | 120 sec |
| | Chest-Supported Dumbbell Row on Incline Bench | 2 × 8–12 | 120 sec |
| | Alternating Dumbbell Curl | 3 × 8–12 | 75 sec |
| | Dumbbell Hammer Curl | 2 × 10–15 | 75 sec |
| Shoulders + Traps | Standing Barbell Overhead Press | 3 × 4–6 | 180 sec |
| | Dumbbell Lateral Raise | 3 × 12–15 | 75 sec |
| | Dumbbell Rear-Delt Fly | 3 × 12–15 | 75 sec |
| | Dumbbell Shrug | 3 × 10–15 | 90 sec |
| Legs + Calves | Barbell Back Squat | 3 × 4–6 | 180 sec |
| | Romanian Deadlift | 3 × 6–10 | 150–180 sec |
| | Dumbbell Reverse Lunge | 2 × 8–12 per leg | 120 sec |
| | Standing Cable Leg Curl (ankle cuff) | 3 × 10–15 per leg | 90 sec |
| | Standing Dumbbell Calf Raise | 4 × 10–15 | 90 sec |

Totals: 12, 13, 12 and 15 working sets. Unilateral sets include both sides.
Cable curls require a low pulley and ankle cuff. No cable lateral raise or chest
press machine is prescribed. Keep 2–3 repetitions in reserve and controlled
technique. No maximal attempts or mandatory failure. Once every working set
reaches the top of its range with that reserve, add the smallest available
weight next session. Reduce load or sets when recovery or technique suffers;
increased fatigue is not a success metric.

## Data migration

The four new templates have versioned IDs distinct from the retired six-session
Hybrid templates. Seeding inserts only missing exercise/template IDs. Existing
records, sets, preferences and drafts are not reset or renamed. Existing active
Hybrid sessions remain resumable. Retired six-session completions stay in history
but do not determine the new rotation; it begins at Chest + Triceps, then follows
completions of the four new sessions. Old planned records remain stored but are
not offered in Choose Workout. Existing unfinished-conditioning cleanup is
unchanged. The persisted track enum remains unchanged for Hive compatibility.

## Phone delivery

Source changes in a cloud checkout or Git branch do not update an installed app.
The repository's Pages workflow deploys from main on push, or via manual dispatch.
This change must first be reviewed and released through the repository's chosen
process. This task does not merge main or deploy production.

For the existing GitHub Pages/PWA installation, after a successful deployment at
https://22tranjason.github.io/SageLift/, open that same site/browser profile on
the phone online and accept the app's Update now prompt when offered. Reopen
and verify the four names and retained history. Data is browser/device local,
not stored in this cloud checkout. Use the existing Backup SageLift Data action
before updating; keep the same origin and do not clear website data or uninstall
to force an update. A native installation instead requires a platform build,
signing and installation through its existing distribution method. A web build
is not a signed Android or iOS package.

## Cloud verification

Validated with Flutter 3.41.5 / Dart 3.11.3: formatting, static analysis, the full
99-test suite, and a release web build at `/SageLift/`. Pub resolution for this
SDK temporarily used its pinned `meta 1.17.0` and `test_api 0.7.10`; the repository
lockfile is preserved (meta 1.18.0 and test_api 0.7.11). No dependencies were added
or committed. Release CI should also validate with its configured stable SDK.
No physical-phone, Android-package or signed iOS build was performed. The web
build reports a missing optional Cupertino font family while completing
successfully; this change does not add Cupertino icons.
