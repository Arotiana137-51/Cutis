# Setup: getting the app onto your iPhone

Everything here is done in a web browser, plus the TestFlight app on your iPhone. No Mac, no Xcode.

When you finish, every change pushed to `main` is built by GitHub, signed, and sent to TestFlight on its own.

**What you need before you start**

- A paid **Apple Developer Program** membership (enrol at <https://developer.apple.com/programs/enroll/>). TestFlight is not available without it.
- You must be the **Account Holder** of that membership (you are, if you enrolled yourself).
- Your iPhone, with the **TestFlight** app installed from the App Store.

**The steps**

| Step | Where | What you do |
| --- | --- | --- |
| 1 | developer.apple.com | Register the bundle ID, note your Team ID |
| 2 | appstoreconnect.apple.com | Create the app record |
| 3 | appstoreconnect.apple.com | Create an API key |
| 4 | github.com | Add 4 secrets |
| 5 | github.com | Put your bundle ID and Team ID in one file |
| 6 | appstoreconnect.apple.com | Add yourself as a tester |
| 7 | github.com | Run the build |
| 8 | iPhone | Install and check |

Keep a note open while you work. You will collect five values:

```
Bundle ID:   ______________________   (step 1)
Team ID:     ______________________   (step 1)
Key ID:      ______________________   (step 3)
Issuer ID:   ______________________   (step 3)
.p8 file:    downloaded to your computer (step 3)
```

---

## Step 1: Register the bundle ID and find your Team ID

The **bundle ID** is the app's permanent unique name inside Apple's systems. It looks like a web address written backwards, for example `com.yourname.tattoopreview`. It cannot be changed later for this app, but it is never shown to users.

1. Open <https://developer.apple.com/account/resources/identifiers/list> and sign in.
2. Click the blue **+** next to "Identifiers".
3. Choose **App IDs**, click **Continue**. Choose **App**, click **Continue**.
4. **Description**: `Tattoo Preview` (any text, only you see it).
5. **Bundle ID**: leave **Explicit** selected and type your bundle ID, for example `com.yourname.tattoopreview`. Use only lowercase letters, digits, dots and hyphens.
6. Leave every capability checkbox as it is. Phase 0 needs none.
7. Click **Continue**, then **Register**.
8. Write the bundle ID in your note.

Now the **Team ID**:

1. Open <https://developer.apple.com/account>.
2. Scroll to **Membership details**.
3. Copy the **Team ID** (10 letters and digits, like `A1B2C3D4E5`) into your note.

## Step 2: Create the app record in App Store Connect

This creates the place where builds are uploaded. Nothing becomes public.

1. Open <https://appstoreconnect.apple.com/apps>.
2. Click the blue **+**, then **New App**.
3. Fill in the form:
   - **Platforms**: tick **iOS**.
   - **Name**: `Tattoo Preview`. This name must be unique across the whole App Store. If Apple says it is taken, use anything else for now, for example `Tattoo Preview Dev`. It can be changed later and does not have to match the name under the icon.
   - **Primary Language**: your choice.
   - **Bundle ID**: pick the one you registered in step 1 from the list. (If it is not in the list yet, wait a minute and reload the page.)
   - **SKU**: any text, for example `tattoopreview-001`. Only you see it.
   - **User Access**: **Full Access**.
4. Click **Create**.

## Step 3: Create an App Store Connect API key

This key lets GitHub talk to Apple on your behalf: create the signing certificate and upload builds.

1. Open <https://appstoreconnect.apple.com/access/integrations/api>.
   (By hand: **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys**.)
2. The first time, the page shows **Request Access**. Click it and accept the terms. Apple says these requests are reviewed, so if you cannot create a key straight away, wait for Apple's confirmation and come back.
3. Click **Generate API Key** (or the **+**).
4. **Name**: `GitHub Actions`.
5. **Access**: **Admin**. (Why Admin: see the note below.)
6. Click **Generate**.
7. Collect three things from this page:
   - **Issuer ID**: shown above the list of keys. Looks like `57246542-96fe-1a63-e053-0824d011072a`. Copy it into your note.
   - **Key ID**: shown in the row of your new key. Looks like `2X9R4HXF34`. Copy it into your note.
   - **The key file**: click **Download** in the row. You get a file named `AuthKey_XXXXXXXXXX.p8`. **Apple lets you download it only once.** Keep it somewhere safe.

> **Why the Admin role?** The first build creates a distribution certificate and a provisioning profile in your Apple account. An Admin key can certainly do that. I could not confirm from Apple's documentation whether the lower "App Manager" role can, so Admin is the choice that will not waste a build. A key's role cannot be edited afterwards; to change it later, revoke this key and create a new one.

## Step 4: Add four secrets to GitHub

Secrets are stored encrypted by GitHub. They are never shown again and never printed in build logs.

1. Open <https://github.com/Arotiana137-51/Cutis/settings/secrets/actions>.
   (By hand: the repository → **Settings** → **Secrets and variables** → **Actions**.)
2. For each row below, click **New repository secret**, type the **Name** exactly, paste the **Secret**, click **Add secret**.

| Name | Secret (what to paste) |
| --- | --- |
| `ASC_KEY_ID` | The Key ID from step 3. |
| `ASC_ISSUER_ID` | The Issuer ID from step 3. |
| `ASC_KEY_P8` | The **whole contents** of the `.p8` file. Open the file in a plain text editor (Notepad on Windows works: right-click → Open with → Notepad), select all, copy, paste. It must include the first line `-----BEGIN PRIVATE KEY-----` and the last line `-----END PRIVATE KEY-----`. |
| `MATCH_PASSWORD` | A long password **you make up now**. It encrypts the signing certificate that the build stores in this repository. Save it in your password manager: it is needed again only if the signing setup ever has to be rebuilt. |

## Step 5: Put your bundle ID and Team ID in the config file

One file holds the app's identity. Everything else reads from it.

1. On GitHub, open the file `ios-app/Config/App.xcconfig` on the `main` branch.
2. Click the pencil icon (**Edit this file**).
3. Replace the two placeholder values with yours:

   ```
   APP_BUNDLE_ID = com.yourname.tattoopreview
   APP_TEAM_ID = A1B2C3D4E5
   ```

   `APP_DISPLAY_NAME` is the name under the app icon. Leave it as `Tattoo Preview` or change it now; it can be changed at any time.
4. Click **Commit changes** and commit directly to `main`.

Committing this file to `main` starts a build automatically (step 7). If you have not done step 6 yet, that is fine: do it while the build runs.

## Step 6: Add yourself as a TestFlight tester

1. Open <https://appstoreconnect.apple.com/apps> and click your app.
2. Click the **TestFlight** tab.
3. In the left sidebar, click the **+** next to **Internal Testing**.
4. Name the group (for example `Me`), tick **Enable automatic distribution**, click **Create**.
   Automatic distribution means every new build goes to this group without you doing anything.
5. In the group, click the **+** next to **Testers**, tick your own account, click **Add**.
6. On your iPhone, open the **TestFlight** app and sign in with the same Apple Account.

## Step 7: Run the build

The build starts by itself whenever something under `ios-app/` changes on `main` (so step 5 already started one). To start one by hand:

1. Open <https://github.com/Arotiana137-51/Cutis/actions/workflows/ios.yml>.
2. Click **Run workflow**, keep the branch as `main`, click the green **Run workflow** button.

Click the run to watch it. It has three parts:

| Part | Runs on | What it does |
| --- | --- | --- |
| **Checks (Linux)** | Linux (cheap) | Checks the config and project files, runs the unit tests. |
| **Ready to build?** | Linux (cheap) | Confirms the config and the 4 secrets are in place and asks Apple whether the key works and the app exists. |
| **Build and upload to TestFlight (macOS)** | macOS (limited minutes) | Builds, signs and uploads. Only starts if the two parts above passed. |

If **Ready to build?** fails, no macOS minutes were used. Open the run's **Summary** page: it lists exactly what is missing, in plain words.

When the macOS part finishes, the Summary shows the version and build number that were uploaded. Apple then processes the build on its side and emails you when it is ready.

## Step 8: Install and check (Phase 0 test checklist)

1. On your iPhone, open **TestFlight**. Tap the app, then **Install**. (If it is not there yet, Apple is still processing. Wait for the email.)
2. Open the app. You should see a dark screen titled **TATTOO PREVIEW**.
3. The large line should read **LiDAR: yes** in orange-red, on an iPhone 12 Pro or newer Pro model.
4. Under **App**: Version `0.1.0`, and a Build number that matches the one on the GitHub run's Summary page.
5. Under **Device**: your iPhone model.
6. Under **ARKit**: every row should say `yes` on a Pro iPhone.
7. Tap **Copy diagnostics**. The button says **Copied**. Paste into Notes to confirm you got the text.

Phase 0 is done when step 3 shows **LiDAR: yes**.

If anything looks different (for example `LiDAR: no` on a Pro phone), tap **Copy diagnostics** and send me the pasted text.

---

## What gets stored where

| Thing | Where it lives | Who can read it |
| --- | --- | --- |
| API key (`.p8`), Key ID, Issuer ID, match password | GitHub Actions secrets | Only build runs in this repository. |
| Signing certificate and provisioning profile | The `ios-signing` branch of this repository, encrypted with `MATCH_PASSWORD` | Useless without the password. |
| Bundle ID, Team ID, app name | `ios-app/Config/App.xcconfig` | Anyone who can read the repository. These are identifiers, not secrets. |

The build creates the `ios-signing` branch by itself on the first run. Do not edit or delete it.

## What a build costs

macOS runners use up included GitHub Actions minutes much faster than Linux runners. I could not confirm the current rate from GitHub's documentation, so check your real usage at <https://github.com/settings/billing> after the first build. The pipeline limits the cost this way:

- The macOS part runs only for `main` or a manual run, never for other branches.
- It runs only after the two Linux parts pass.
- It stops itself after 30 minutes at the latest.
- It does not wait for Apple to process the build.
- Changes that do not touch `ios-app/` do not start it at all.

## If something goes wrong

**"Ready to build?" failed.** Open the run's Summary. Each line names the secret or config value to fix and the step of this guide that covers it. Fix it, then run the workflow again (step 7).

**"Apple rejected the API key (HTTP 401)".** `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` do not belong together, or the key was revoked. Re-enter all three from the same key. If you no longer have the `.p8` file, create a new key (step 3).

**"not allowed" (HTTP 403).** Either the key's role is too low (create a new one with **Admin**), or Apple is waiting for you to accept an updated agreement: open <https://appstoreconnect.apple.com/business> and <https://developer.apple.com/account> and accept anything pending.

**"No app with bundle ID … exists".** The app record from step 2 is missing, or `APP_BUNDLE_ID` in the config file is not spelled exactly like the bundle ID you registered.

**The macOS build failed.** Send me the link to the run. I can read the build log from there. The Summary page also shows the main error message.

**"Signing files were not saved".** The build created a certificate with Apple but could not store it in the `ios-signing` branch. Do not re-run yet.
1. Open <https://github.com/Arotiana137-51/Cutis/settings/rules> and check that no rule blocks creating or pushing to the `ios-signing` branch.
2. Open <https://developer.apple.com/account/resources/certificates/list> and revoke the newest certificate of type **Distribution** (the one just created).
3. Run the workflow again.

**"Maximum number of certificates" (or similar) from Apple.** Apple limits how many distribution certificates an account can have. Open <https://developer.apple.com/account/resources/certificates/list>, revoke the **Distribution** certificates you do not use, then run the workflow again.

**The build uploaded but never appears in TestFlight.** Check your email: Apple reports problems with an uploaded build by email (subject starting with "ITMS"). Forward me that text. Also check App Store Connect → your app → **TestFlight**: a build marked "Processing" just needs more time.

**You lost `MATCH_PASSWORD`, or want to start signing from scratch.**
1. Delete the `ios-signing` branch at <https://github.com/Arotiana137-51/Cutis/branches>.
2. At <https://developer.apple.com/account/resources/certificates/list>, revoke the **Distribution** certificate.
3. At <https://developer.apple.com/account/resources/profiles/list>, delete the profile named `match AppStore <your bundle ID>`.
4. Set a new `MATCH_PASSWORD` secret (step 4) and run the workflow again.
