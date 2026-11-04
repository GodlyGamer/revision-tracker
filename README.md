# Revision Tracker

Tells you what to revise next so no module gets left behind. One file, `index.html`, runs in any browser. The same file is wrapped in a small iOS app (a full-screen web view) for sideloading.

## On a laptop
Double-click `index.html`. Data is saved in that browser. Use **Export backup** regularly.

## On the iPhone (sideloaded IPA)

### Getting the IPA
GitHub Actions builds it on every push to `main` (or by hand: Actions tab, "build", Run workflow). Open the finished run, download the `RevisionTracker.ipa` artifact (a zip), and unzip it.

### Installing with Sideloadly (Windows)
1. Plug in the iPhone and open Sideloadly.
2. Drag `RevisionTracker.ipa` in and sign in with your Apple ID.
3. **Use the same Apple ID every time** and leave "change bundle ID" off. The bundle ID is `com.youssoufdiallo.revisiontracker`. If either changes, iOS treats it as a new app with empty data.
4. Install over the existing app to update. Your data stays.
5. A free Apple ID signing lasts 7 days. Re-sign by repeating the steps. Your data stays.

Developer Mode must be on (Settings > Privacy & Security), and the developer profile trusted (Settings > General > VPN & Device Management).

### Where the iPhone app keeps your data
- `revision-tracker-data.json` in the app's Documents folder. You can see it in **Files > On My iPhone > Revision**.
- **Export backup** opens the share sheet (Save to Files, AirDrop, Mail) and also keeps a copy in `Backups/` in the same folder.
- **Import backup** opens the Files picker.
- Deleting the app deletes its data. Export first.

## Updating the app
Edit `index.html`, push to `main`, download the new IPA, and install it over the old one with Sideloadly.

## Files
```
index.html                      the whole app (HTML, CSS, JS)
project.yml                     XcodeGen spec for the iOS wrapper
App/RevisionTrackerApp.swift    WKWebView host: file storage, share sheet, alert/confirm dialogs
App/Resources/                  Info.plist, app icon, launch colour
scripts/make-icon.js            regenerates the app icon (node scripts/make-icon.js)
.github/workflows/build.yml     builds the unsigned IPA on macOS
```
