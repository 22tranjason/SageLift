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
| | Dumbbell Fly (Flat Bench) | 3 × 10–15 | 75 sec |
| | Overhead Triceps Extension (dumbbell) | 3 × 10–15 | 75 sec |
| | Cable Triceps Pushdown | 3 × 10–15 | 75 sec |
| Back + Biceps | Barbell Bent-Over Row | 3 × 6–8 | 150–180 sec |
| | Cable Lat Pulldown | 3 × 8–12 | 120 sec |
| | Chest-Supported Dumbbell Row on Incline Bench | 3 × 8–12 | 120 sec |
| | EZ-Bar Curl | 3 × 8–12 | 75 sec |
| | Dumbbell Hammer Curl | 3 × 10–15 | 75 sec |
| Shoulders + Traps | Standing Barbell Overhead Press | 3 × 4–6 | 180 sec |
| | Dumbbell Lateral Raise | 3 × 12–15 | 75 sec |
| | Dumbbell Rear-Delt Fly | 3 × 12–15 | 75 sec |
| | Dumbbell Shrug | 3 × 10–15 | 90 sec |
| Legs + Calves | Barbell Back Squat | 3 × 4–6 | 180 sec |
| | Romanian Deadlift | 3 × 6–10 | 150–180 sec |
| | Dumbbell Reverse Lunge | 2 × 8–12 per leg | 120 sec |
| | Standing Dumbbell Calf Raise | 4 × 10–15 | 90 sec |

Totals: 15, 15, 12 and 12 working sets. Unilateral sets include both sides.
The Back + Biceps v2 update uses three sets for the supported row and hammer
curl and replaces alternating curls with EZ-bar curls (3 × 8–12).
The October 27 equipment update replaces cable chest fly with flat-bench dumbbell
fly, adds cable triceps pushdown, and removes hamstring walkouts. Completed
history and active or drafted sessions retain their original exercises. Existing
exercise catalogue entries remain available for history and backup references.
Keep 2–3 repetitions in reserve and controlled
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
Production release uses the reviewed PR and the existing main-triggered workflow.
A Git branch alone does not publish the app.

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
100-test suite, and a release web build at `/SageLift/`. Pub resolution for this
SDK temporarily used its pinned `meta 1.17.0` and `test_api 0.7.10`; the repository
lockfile is preserved (meta 1.18.0 and test_api 0.7.11). No dependencies were added
or committed. Release CI should also validate with its configured stable SDK.
No physical-phone, Android-package or signed iOS build was performed. The web
build reports a missing optional Cupertino font family while completing
successfully; this change does not add Cupertino icons.


## Release review

The deployment workflow uses `subosito/flutter-action@v2`, channel `stable`,
without a fixed Flutter version. The saved cloud SDK is Flutter 3.41.5 / Dart
3.11.3. The workflow deploys on a push to main or manual dispatch; it does not
run branch-only checks. Do not dispatch it as a harmless CI check: successful
completion includes a production Pages deployment.

The configured URL and base path are `https://22tranjason.github.io/SageLift/`
and `/SageLift/`. Live URL and `version.json` reads were blocked by HTTP 403
in this environment; the browser tool could not access them either. The shell GitHub Actions query was also forbidden. The connected GitHub tool
successfully verified the last main deployment: run 37403118380, conclusion
success, SHA 224d206bd0f92836a34349ffa2fe4197f693c266. Its deploy log records the
environment URL `https://22tranjason.github.io/SageLift/`, confirming site identity.
The prior build log used Flutter stable 3.47.6. Its public Linux archive and
release manifest returned HTTP 404 here, so local checks use the saved 3.41.5 SDK.
Current live HTTP availability and served version remain unverified. Git branch
pushes and remote ref reads work.

After explicit PWA/release confirmation, review the branch and use the agreed
release process. If a main merge is authorized, a normal reviewed merge triggers
the workflow; wait for its build and deploy jobs, inspect the resulting Pages
URL and `version.json`, and verify its SHA matches the release. A separately
authorized manual dispatch can also deploy a selected ref, but is a production
action. Do not run it before publish permission. Then back up on the phone,
update the same installed PWA online, and verify history and an existing active
draft before starting the desired session manually. A Thursday session remains
an explicit choice; the suggested rest schedule is unchanged.


A final Hive regression test now seeds twice, closes and reopens storage, and
checks the exact saved settings JSON, theme preference, workout and set IDs,
draft values, resumability, and completion into the new rotation. Existing Hive
repository tests now clear their test boxes between cases to avoid state leaking
from one migration scenario into another. This test-only cleanup is not present
in application code.

Publication was subsequently authorized for the existing iPhone Home Screen PWA.
Shell HTTP reads of the site and version.json return 403, including outside the
filesystem sandbox. The parent subsequently verified the existing site in the
permitted cloud browser: it loads the expected SageLift dashboard without a login
or 403. This resolves the live-access prerequisite. Release can proceed through
the existing workflow; the parent browser will verify the updated served UI.
