# Decisions log

One line for every choice the brief did not specify. Newest phase at the bottom.

## Phase 0

| # | Decision | Why |
| --- | --- | --- |
| 1 | The Xcode project, target and Swift module are named **Cutis** (the repository's name). The name users see is separate, in the config file. | The app name is still a placeholder; renaming a target later is disruptive, renaming a display name is one line. |
| 2 | App name, bundle ID, Team ID and version live in `ios-app/Config/App.xcconfig`. | Xcode reads this format directly, and the build scripts parse the same file, so there is exactly one place to edit. |
| 3 | The config file ships with `BUNDLE_ID_PLACEHOLDER` and `TEAM_ID_PLACEHOLDER`; a build refuses to start until they are replaced. | A placeholder must never reach Apple. |
| 4 | Signing uses **fastlane match** together with an **App Store Connect API key** (the brief allowed either). | The API key means no Apple ID password or two-factor codes in CI. match keeps one certificate and reuses it, instead of creating a new one on every build. |
| 5 | match stores the encrypted certificate and profile on an `ios-signing` branch of **this** repository, pushed with the workflow's built-in token. | The usual setup needs a second private repository and a personal access token. This needs neither: one less thing to create and one less secret. |
| 6 | SETUP.md asks for an API key with the **Admin** role. | Creating a distribution certificate needs enough rights. I could not confirm from Apple's documentation that "App Manager" is enough, and a wrong guess costs a macOS build. Listed in OPEN_QUESTIONS.md. |
| 7 | Signing is "manual" in `project.yml`, with the profile name `match AppStore <bundle ID>`. | That is the name match generates. A unit test checks the two stay in step. |
| 8 | The macOS job is pinned to the `macos-26` runner (Xcode 26). | Apple has required Xcode 26 for uploads since 28 April 2026. Pinning avoids a surprise when GitHub moves `macos-latest`. Apple has announced the iOS 27 SDK will be required from April 2027: the runner must move before then. |
| 9 | The build number is the UTC date and time (`202611160915`). | TestFlight requires each build number to be higher than the last. A clock always is, even if a workflow is re-run or renamed. It is shown in the app so you can tell builds apart. |
| 10 | The upload does not wait for Apple to finish processing the build. | Waiting can take a long time on a paid macOS runner and tells us nothing new: Apple emails the result. |
| 11 | `ITSAppUsesNonExemptEncryption` is set to `false`. | Without it, every build stops in TestFlight until an export-compliance question is answered by hand. True for Phase 0 (no encryption code). **Must be reviewed in Phase 2** when scan encryption is added. |
| 12 | iPhone only (no iPad layout), portrait only, dark appearance only. | The brief targets an iPhone Pro and a dark theme. iPad support adds App Store requirements for nothing. |
| 13 | Swift language mode 5 for now, not Swift 6 strict concurrency. | Strict-concurrency errors only show up in a real Mac build, and each of those costs minutes. Revisit once the pipeline is proven. |
| 14 | One pure-Swift package, `AppCore`, with XCTest unit tests that run on a Linux runner. | Proves the "logic in packages, tested cheaply on Linux" structure in Phase 0, before real logic depends on it. |
| 15 | `ios.yml` has three jobs: Linux checks (every push touching `ios-app/`), a Linux "Ready to build?" gate, then the macOS build (only `main` or manual). | macOS minutes are only spent after everything checkable on Linux has passed. |
| 16 | The "Ready to build?" gate makes a live call to Apple to confirm the key works, the bundle ID is registered and the app record exists. | These are the most likely first-time setup mistakes. Finding them on Linux costs seconds instead of a failed macOS build. |
| 17 | TestFlight builds run one at a time and a running build is never cancelled. | A build cancelled while creating the signing certificate would leave an orphan certificate in the Apple account. |
| 18 | After match runs, the build checks the signing files really were saved, and stops if not. | match only logs a failed save and carries on, which would create a new certificate on every build until Apple's limit is hit. |
| 19 | fastlane is pinned through `Gemfile.lock` (2.241.2) and cached. XcodeGen is installed with Homebrew at build time and is not pinned. | fastlane is the fragile part and benefits from pinning. Pinning XcodeGen is possible later if a new release ever breaks a build. |
| 20 | "LiDAR: yes" means ARKit reports **both** scene depth and mesh reconstruction as supported. If only one is, the screen says "partial". | Both are needed for the scan. A disagreement would be unexpected and worth seeing. |
| 21 | The list of iPhone model names in `AppCore` is cosmetic. Whether a feature is available always comes from ARKit on the device. | A wrong or missing name must never change behaviour. Unknown models show their raw code. |
| 22 | The Phase 0 screen has a "Copy diagnostics" button, which the brief did not ask for. | You cannot debug on the device, so even Phase 0 needs a way to send me what the phone reports. The full hidden debug screen is Phase 1. |
| 23 | A placeholder app icon was generated (a ring in the accent colour). | App Store Connect rejects any upload without an icon. Replace with real artwork whenever it exists. |
| 24 | The camera permission text is already in `Info.plist`, though Phase 0 never opens the camera. | The app links ARKit, and Apple checks uploads for the matching permission text. It is needed from Phase 1 anyway. |
| 25 | Design tokens are in `ios-app/App/Design/Theme.swift`. Phase 0 uses system fonts; Anton, DM Sans and JetBrains Mono are bundled in Phase 1. | Phase 0 is "pipeline proof, nothing else". The font functions are already in the tokens file, so swapping the real fonts in is a one-file change. |
| 26 | The repository's Android-template `.gitignore` was replaced with one for this project (iOS, Python, Node, and signing files). | The old one did not ignore generated Xcode projects, build output or key files. |
| 27 | Not started in Phase 0, on purpose: the `FittedBody` schema, the Anny repository check, backend, admin panel, `backend.yml`, `admin.yml`. | The brief says Phase 0 only. The schema and the Anny check come first in the next phases that need them. |
