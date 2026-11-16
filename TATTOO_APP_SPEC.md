# Tattoo Preview App: implementation brief for Claude Code

Read this whole file before writing code. Build one phase at a time, in order, and stop at the end of each phase so I can test on my iPhone. Do not start a later phase early.

## 1. What we are building

An iPhone app that scans a real body part with LiDAR, places a tattoo design on the 3D shape at real size, and shows how it looks when the body moves and as the body changes (weight, age, ink aging). It is a reality check before a permanent tattoo, and a planning tool for people who already have tattoos.

Three surfaces:

1. **iOS app** for clients and tattoo artists (same app, role decided by plan).
2. **Backend API** with background workers for heavy 3D processing.
3. **Admin panel** in the browser, for the team only.

"Cutis" (the repository name) is the working app name. Treat the app name, bundle ID and Apple Team ID as placeholders (`[APP_NAME]`, `[BUNDLE_ID]`, `[TEAM_ID]`) and keep them in one config file.

## 2. Hard constraints

- **I have no Mac.** Everything must build in CI. Never ask me to open Xcode. The Xcode project must be generated from a text file (use XcodeGen with `project.yml`), never hand-edited `.xcodeproj`.
- **Builds run on GitHub Actions macOS runners** and are delivered to my phone through TestFlight (fastlane). The repo is private. macOS minutes are limited, so: run iOS builds only on pushes to `main` or on manual trigger, cache dependencies, and keep everything that can be tested without a Mac (backend, admin, pure-Swift logic packages on Linux where possible) in separate, cheap Linux jobs.
- **I cannot debug live on the device.** So the app needs a hidden debug screen (shake or 5 taps on the logo) showing logs, device capabilities, scan stats and the last error, with a "copy to clipboard" button. Log generously.
- **Test device:** an iPhone Pro with LiDAR (12 Pro or newer). The Simulator cannot do camera or LiDAR, so do not rely on it for scanning.
- **Minimum iOS:** 17.0 (needed for Vision 3D body pose).
- **No LiDAR fallback is mandatory.** Add a debug switch "pretend this phone has no LiDAR" so I can test the fallback on the same phone.
- **Body model licence:** use **Anny** (NAVER LABS Europe, Apache 2.0). Do **not** use SMPL / SMPL-X or Anny's optional SMPL-X-compatible add-on; those are non-commercial without a paid licence. Before designing around Anny, read its repo and confirm what it exports (mesh, skeleton, skin weights, shape parameters) and tell me if anything here does not match.
- **Privacy by design:** body scans are sensitive. Scans are stored encrypted, in their own bucket, never sent to analytics, never used for marketing. Account deletion must delete everything.

## 3. Repository layout

```
/ios-app            Swift app, project.yml (XcodeGen), fastlane/
/ios-app/Packages   Pure-Swift packages (measurement maths, ink-aging rules, models) with unit tests
/backend            FastAPI app, workers, Alembic migrations, tests
/admin-web          Next.js admin panel
/infra              docker-compose for local dev (API, Postgres, Redis, MinIO)
/.github/workflows  ios.yml, backend.yml, admin.yml
/docs               this file, decisions log, API schema
```

Keep a `docs/DECISIONS.md` and add one line every time you make a choice I did not specify.

## 4. Tech stack

| Layer | Choice |
| --- | --- |
| iOS UI | Swift, SwiftUI |
| Scanning | ARKit world tracking with `sceneDepth` (LiDAR depth map is 256 x 192 per frame, so fuse many frames) and scene mesh reconstruction |
| Joints | Apple Vision 3D body pose on captured color frames. LiDAR depth and ARKit body tracking do not run together |
| 3D rendering | RealityKit, Metal shaders for the tattoo texture |
| Payments | StoreKit 2 subscriptions |
| Backend | Python, FastAPI, PostgreSQL, Redis job queue, S3-compatible storage (MinIO locally) |
| Workers | Python + PyTorch, scan fusion and Anny fitting |
| Admin | Next.js (React), same API, admin roles |
| CI | GitHub Actions; fastlane `match` or App Store Connect API key for signing; TestFlight upload |

## 5. Core concept the whole app depends on

Every capture path ends in the same object: a **FittedBody** (mesh + UV map + skeleton + skin weights + shape parameters + real-world scale in cm + quality score). Placement, movement and aging only ever read a FittedBody and never care where it came from.

Capture paths:

1. **LiDAR scan** (precision mode).
2. **Typed measurements** (fallback: height, weight, circumferences and length of the body part).
3. **Camera only** (later phase).

Define the `FittedBody` format first, as a shared schema used by iOS and backend, and write it down in `/docs`.

## 6. Phases

### Phase 0: pipeline proof (do this first, nothing else)

Goal: prove a build reaches my phone.

- XcodeGen project, one SwiftUI screen showing app version, device model, and whether `ARWorldTrackingConfiguration` supports `sceneDepth` and mesh reconstruction.
- GitHub Actions workflow that generates the project, builds, signs and uploads to TestFlight.
- A `docs/SETUP.md` listing exactly which secrets I must add to GitHub and where to get each one in App Store Connect, step by step, assuming I only have a browser.
- **Done when:** I install from TestFlight and see "LiDAR: yes" on my phone.

### Phase 1: on-device prototype (no backend)

- Guided LiDAR scan of a forearm: coverage percentage, distance hint, "move slower" hint, finish/restart.
- Fuse the scan into a mesh on device (ARKit mesh anchors are fine for now). Show it in 3D, rotatable.
- Measure circumferences at wrist, mid-forearm, below elbow, and forearm length, in cm. Values are user-editable.
- Import a PNG design from Photos/Files, project it onto the mesh as a decal, drag / scale / rotate, show its real size in cm.
- Save scans and placements locally.
- Debug screen (see constraints).
- **Done when:** I scan my forearm, the wrist measurement is within 1 cm of a tape measure, and a PNG sits on the 3D arm at a size I can read in cm.

### Phase 2: backend, accounts, fitted body

- FastAPI, Postgres, storage, job queue, Docker Compose for local dev.
- Sign in with Apple and email. In-app account deletion.
- Upload raw scan (depth frames, color frames, camera poses), fuse on the server, fit Anny to it, return a FittedBody. Keep scan detail the model cannot represent as a displacement layer.
- Typed-measurements path producing a FittedBody.
- Design upload with background removal and line cleanup.
- **Done when:** both capture paths give a body I can place a design on, and the LiDAR one has a quality score.

### Phase 3: movement simulator

- Pose the FittedBody skeleton on device: preset poses per body part, a joint slider with realistic limits, play/pause loop.
- Stretch map overlay (stretched vs squeezed skin under the design) with a legend, plus a one-line plain-language insight.
- **Done when:** bending the wrist visibly deforms the design and the stretch map follows.

### Phase 4: aging and body change

- Body: weight slider (kg), muscle slider, age steps (+5, +10, +20, +30 years) driven by Anny shape parameters, keeping the user's scan detail.
- Ink: line spread growing with years (stronger on thin lines), per-color fade, sun exposure setting (low / medium / high), and a **line-merge warning** that marks spots where lines will likely blur together.
- Side-by-side Now vs future view. Every aged view carries the label "Illustration, not a prediction."
- Aging rule values come from the backend config so the admin can tune them without an app release. Ship with clearly marked placeholder values; real rates will be tuned with tattoo artists.

### Phase 5: plans, artist tools, admin

- StoreKit 2 subscriptions, restore purchases, server-side verification:
  - Free: one scan, plus any preview an artist sends.
  - Client Plus: $4.99 / month or $29.99 / year.
  - Artist Pro: $19.99 / month or $179.99 / year, 14-day free trial.
  - Studio: $49.99 / month, up to 3 artists.
- Artist: client list with status, versions of a placement, send a preview to a client with a note, client approves or asks for changes, real-size stencil export (flattened from the 3D curve, A4 / Letter, mirror option, 1 cm scale bar, PDF).
- Existing tattoos: detect or add them to the model, plan a new piece around them, show the gap in cm.
- AI design generation through a third-party image API called from the backend, behind an explicit consent step.
- Admin panel: dashboard, users (search, disable, delete data), scans (quality, failure reason, rerun fitting; body images hidden by default and every view logged), flagged designs (keep / remove), simulation settings, pricing, admin accounts with roles and two-factor login, audit log of every admin action.

## 7. Data model (starting point)

`users`, `body_profiles`, `scans`, `fitted_bodies`, `measurements`, `designs`, `placements`, `simulations`, `purchases`, `artist_clients`, `shared_previews`, `admin_audit_log`. Use Alembic migrations from the first table.

## 8. API (starting point)

```
POST   /auth/login
POST   /scans                       create scan, get upload URL
POST   /scans/{id}/complete         start fusion and fitting
GET    /scans/{id}                  status, quality, measurements
PATCH  /scans/{id}/measurements
POST   /bodies/manual               body from typed measurements
POST   /designs                     upload
POST   /designs/generate            AI options
POST   /placements
POST   /placements/{id}/simulate
POST   /previews                    artist sends to client
POST   /purchases/verify
DELETE /me                          delete account and all data
/admin/*                            admin role + two-factor
```

Generate an OpenAPI schema and keep the iOS client types in sync with it.

## 9. Screens and visual design

16 screens exist as a design mock-up; I will attach screenshots. Match them.

- Client: Welcome (pick body part), LiDAR scan, Measurements, Choose a design, Place, Movement, Aging and weight, Plans, Your tattoos, Plan around them, Enter measurements (no LiDAR), Preview from your artist.
- Artist: Clients, Send preview, Real-size stencil.
- Browser: Admin dashboard.

Design tokens (dark theme only for now):

| Token | Value |
| --- | --- |
| Background | `#141210` |
| Surface | `#1E1B18` |
| Border | `#2E2925`, strong `#6E655B` |
| Text | `#EFE8DC`, secondary `#ABA195` |
| Accent | `#E5573B` (text on accent is `#141210`) |
| Warning | `#E8A33D` |
| Stretch map | stretched `#F28C38`, squeezed `#4F8BE8` |
| Fonts | Anton (display, uppercase), DM Sans (UI), JetBrains Mono (all measurements and numbers) |
| Shape | 14 px button radius, 20 px card radius, 44 pt minimum touch target |

Bundle the fonts in the app. Put tokens in one Swift file and one CSS file.

## 10. App Store rules that affect the code

- ARKit depth and body data may not be used for advertising, marketing or data mining.
- Sending a user's photo or prompt to an outside AI service needs clear disclosure and explicit permission first.
- Account deletion must be possible inside the app.
- If a social login other than Apple is added, Sign in with Apple must also be offered.
- Unlocking paid features uses In-App Purchase.
- Camera usage description string must explain the body scan plainly.

## 11. How to work with me

- I am not an iOS developer. Explain decisions briefly and in plain words.
- I can only test by installing from TestFlight, so at the end of each phase give me a short test checklist ("do this, you should see that").
- Each CI build costs limited minutes. Batch changes; do not push ten small commits to `main` in a row. Make sure Swift compiles as far as you can check before triggering an iOS build, and put as much logic as possible into pure-Swift packages with unit tests.
- When something fails on device, ask me for the debug-screen text rather than guessing.
- Never invent measurements, accuracy figures or aging rates. Where a real value is unknown, use a named placeholder and list it in `docs/OPEN_QUESTIONS.md`.
- Legal documents (privacy policy, terms) are out of scope for now; leave clearly marked placeholders.

## 12. Open questions to track

- Accuracy needed per body part in cm, and whether iPhone LiDAR reaches it in our tests.
- Can one person scan their own forearm or calf reliably?
- Exactly what Anny exports, and how weight / age parameters map to its shape space.
- How to run shape and pose changes on device in real time (export blend shapes and skin weights from the backend, or evaluate on the server).
- Which image-generation API, which cloud provider.
- Final app name, bundle ID, colors.

**Start with Phase 0 only.**
