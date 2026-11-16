# Open questions

Things nobody knows yet. Nothing here may be replaced by a guess: each item needs a test result, a document, or your decision.

## Placeholders in the code

| Placeholder | Where | Replaced by |
| --- | --- | --- |
| `[APP_NAME]` = "Tattoo Preview" (working name) | `APP_DISPLAY_NAME` in `ios-app/Config/App.xcconfig` | Your final app name |
| `[BUNDLE_ID]` = `BUNDLE_ID_PLACEHOLDER` | `APP_BUNDLE_ID` in the same file | The bundle ID you register (SETUP.md step 1) |
| `[TEAM_ID]` = `TEAM_ID_PLACEHOLDER` | `APP_TEAM_ID` in the same file | Your Apple Team ID (SETUP.md step 1) |
| App icon | `ios-app/App/Resources/Assets.xcassets/AppIcon.appiconset` | Real artwork |
| Privacy policy, terms | Not written (out of scope for now) | Legal documents, before any public release |

## From the brief (section 12)

1. **Accuracy.** What accuracy does each body part need, in cm, and does iPhone LiDAR reach it in our own tests? (First data: Phase 1, wrist within 1 cm of a tape measure.)
2. **Self-scanning.** Can one person scan their own forearm or calf reliably?
3. **Anny.** Exactly what does it export (mesh, skeleton, skin weights, shape parameters), and how do weight and age map to its shape space? To be checked in its repository before any design depends on it.
4. **Real-time shape and pose on device.** Export blend shapes and skin weights from the backend, or evaluate on the server?
5. **Providers.** Which image-generation API, which cloud provider?
6. **Identity.** Final app name, bundle ID, colours.

## Found during Phase 0

7. **Lowest API key role that works.** Does an App Store Connect API key with the "App Manager" role have the rights to create a distribution certificate and provisioning profile? Apple's role pages did not answer this clearly. SETUP.md uses Admin until it is confirmed.
8. **Cost of one iOS build.** How many of your included GitHub Actions minutes does one TestFlight build use? I could not read GitHub's current billing page. Measure from the billing page after the first build.
9. **Next Xcode requirement.** Apple has announced that uploads will need the iOS 27 SDK from April 2027. Apple's two pages currently disagree on the minimum deployment target that comes with it. The runner in `ios.yml` must move to Xcode 27 before that date.
10. **Swift 6 language mode.** When to turn on strict concurrency checking (see DECISIONS.md, #13).
11. **Export compliance.** Once scans are encrypted (Phase 2), is the app still exempt from export-compliance paperwork, or does `ITSAppUsesNonExemptEncryption` have to change? Needs a proper answer, not an assumption.
