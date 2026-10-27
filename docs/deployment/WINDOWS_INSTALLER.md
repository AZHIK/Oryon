# Windows installer

The Flutter client ships to Windows as an Inno Setup installer
(`Oryon-<version>-windows-x64-setup.exe`). The installer is built by
[`.github/workflows/windows-installer.yml`](../../.github/workflows/windows-installer.yml);
this document explains what that workflow does, how to run it, and how to build
the same artifact by hand.

## What the workflow produces

| Item | Value |
|---|---|
| Installer script | `apps/restaurant_app/windows/installer/oryon.iss` |
| Artifact (GitHub Actions) | `oryon-windows-installer` |
| Installer file | `Oryon-1.0.0-windows-x64-setup.exe` |
| Stable release asset | `Oryon-windows-x64-setup.exe` (copy attached to the GitHub release) |
| Checksums | `SHA256SUMS.txt` next to the installer |
| Local output directory | `apps/restaurant_app/build/windows/installer/` |

The installer places the app in `Program Files\Oryon`, adds Start-menu and
optional desktop shortcuts, registers an uninstaller, and installs the Microsoft
Visual C++ runtime only when the target machine is missing it.

## When it runs

- **Manual** — Actions → *Windows installer* → Run workflow.
- **Tag push** — pushing `v1.0.0` builds the installer and publishes a GitHub
  release with the `.exe` and `SHA256SUMS.txt` attached.
- **Pull request** — any change under `apps/restaurant_app/**` builds the
  installer as a downloadable artifact so Windows regressions are caught before
  merge. No release is published.

File versions come from `apps/restaurant_app/pubspec.yaml`:

```yaml
version: 1.0.0+1   # installer/exe version 1.0.0, build number 1
```

The build fails if a tag does not match that version (tag `v1.0.0` requires
`version: 1.0.0+…`). Bump `pubspec.yaml` first, then tag the commit.

## Publishing to the website

The public download page does not embed the installer. It probes
`/downloads/latest.json` and the stable alias
`/downloads/Oryon-windows-x64-setup.exe` at runtime, so publishing a build flips
the page from “Coming soon” to “Download for Windows” without rebuilding the
site.

### Get and verify the artifact

Download the workflow artifact or the GitHub Release asset:

```bash
gh run download <run-id> -n oryon-windows-installer -D ./dist

# or, for a tagged release
gh release download v1.0.0 \
  -p 'Oryon-1.0.0-windows-x64-setup.exe' \
  -p 'SHA256SUMS.txt' \
  -D ./dist

cd dist
sha256sum -c SHA256SUMS.txt
```

### Upload and publish

```bash
scp ./dist/Oryon-1.0.0-windows-x64-setup.exe \
  <deploy-user>@<VPS_IP>:/tmp/

ssh <deploy-user>@<VPS_IP>
cd <website-dir>
bash scripts/publish-release.sh /tmp/Oryon-1.0.0-windows-x64-setup.exe
```

Do **not** set `ORYON_DOWNLOAD_BASE_URL` in production; the default is
`https://oryonfoods.com/downloads`. `<website-dir>` is
`<repo-path>/apps/website` for a git checkout, or `/opt/oryon-website` for the
copy-only deployment.

### Verify

```bash
curl -sS https://oryonfoods.com/downloads/latest.json | jq
curl -sSI https://oryonfoods.com/downloads/Oryon-windows-x64-setup.exe
```

Then open <https://oryonfoods.com/download/> in a browser and hard-reload. The
badge should read **Available now** and the button should download the
installer.

> The flip happens in the browser. `curl` on `/download/` always shows the
> server-rendered “Coming soon” text; verify the files under `/downloads/` with
> `curl`, and the badge in a browser.

### Rollback

Re-run the script with an older installer that is still on the server:

```bash
cd <website-dir>
bash scripts/publish-release.sh \
  /srv/oryon/downloads/Oryon-0.9.0-windows-x64-setup.exe
```

The script writes the versioned file, the stable alias, `SHA256SUMS.txt` and
`latest.json`. It is idempotent and keeps older versions for rollback. Never
reuse a version with different bytes: versioned files are cached as immutable.

The GitHub release also carries a constant-name copy, so this URL always works
for the newest tag:

```text
https://github.com/AZHIK/Oryon/releases/latest/download/Oryon-windows-x64-setup.exe
```

See [the website deployment guide](../../apps/website/DEPLOYMENT.md#6-publishing-the-windows-installer)
for the one-time host setup, directory permissions, verification and
troubleshooting.

## Backend URLs

Release builds reject requests without explicitly supplied service URLs
(`lib/config/api_config.dart`), so the workflow always passes three
`--dart-define` values. They default to the production domains and can be
overridden with repository variables of the same name
(Settings → Secrets and variables → Actions → Variables):

| Variable | Default |
|---|---|
| `IDENTITY_API_BASE_URL` | `https://auth.oryonfoods.com/api/v1` |
| `INVENTORY_API_BASE_URL` | `https://inventory.oryonfoods.com/api/v1` |
| `POS_API_BASE_URL` | `https://pos.oryonfoods.com/api/v1` |

## Building locally on Windows

Prerequisites: Flutter 3.47.1, Visual Studio 2022 with the *Desktop development
with C++* workload, and Inno Setup 6.3 or newer.

```powershell
cd apps\restaurant_app

flutter pub get
flutter build windows --release `
  --build-name=1.0.0 --build-number=1 `
  --dart-define=IDENTITY_API_BASE_URL=https://auth.oryonfoods.com/api/v1 `
  --dart-define=INVENTORY_API_BASE_URL=https://inventory.oryonfoods.com/api/v1 `
  --dart-define=POS_API_BASE_URL=https://pos.oryonfoods.com/api/v1

& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" `
  /DAppVersion=1.0.0 /DAppBuild=1 windows\installer\oryon.iss
```

The result is `build\windows\installer\Oryon-1.0.0-windows-x64-setup.exe`. The
installer expects the Flutter bundle in `build\windows\x64\runner\Release`, which
is where `flutter build windows` puts it.

To make the installer self-sufficient on machines without the Visual C++
runtime, download the redistributable into the payload directory before running
ISCC; otherwise that prerequisite is skipped:

```powershell
mkdir windows\installer\redist
Invoke-WebRequest https://aka.ms/vs/17/release/vc_redist.x64.exe `
  -OutFile windows\installer\redist\vc_redist.x64.exe
```

## Local data and uninstall

The encrypted Drift database is application state, not a user document, so the
app does not keep it in the user's Documents folder. On desktop it uses
`getApplicationSupportDirectory()`:

| Platform | Database |
|---|---|
| Windows | `%APPDATA%\Oryon Foods\Oryon\app.db` (plus `-wal`/`-shm`) |
| Linux | `$XDG_DATA_HOME/oryon/app.db` |
| macOS | `~/Library/Application Support/…/app.db` |
| Android / iOS | app-sandboxed documents directory (unchanged) |

On Windows that path is derived from `CompanyName`/`ProductName` in
`windows/runner/Runner.rc`, and `AppData` is hidden in Explorer by default. The
file itself is SQLCipher-encrypted; the key lives in `flutter_secure_storage`
(`*.secure` files in the same directory, backed by the Windows credential
store).

Uninstalling removes that directory for every local Windows profile
(`CurUninstallStepChanged` in `oryon.iss`), including the database, its sidecar
files and the encryption key. Deleting user data is intentional: **any sales
that were never synced are discarded by an uninstall**, so sync before removing
the app from a terminal that has offline work.

Upgrading from an earlier desktop build puts the database in Documents; the app
moves it into the new location on first launch, so no data is lost and nothing
is left behind in Documents.

## Code signing

The workflow produces an unsigned installer, so Windows SmartScreen shows a
publisher warning on first run. To sign it, add a code-signing certificate as
repository secrets and sign both `oryon.exe` and the installer with `signtool`
before the upload step. The signing certificate (`/f`, password `/p`,
timestamp server `/tr`) is issued by a CA such as DigiCert or SSL.com; an
EV certificate removes the warning immediately, a standard certificate builds
reputation over time.

## Branding

- Window title and executable name: `windows/runner/main.cpp` (`L"Oryon"`) and
  `BINARY_NAME` in `windows/CMakeLists.txt` (`oryon.exe`).
- File properties (company, product, copyright): `windows/runner/Runner.rc`.
- Icons: replace `windows/runner/resources/app_icon.ico` (multi-size ICO) and
  `assets/` brand images. The current icon is Flutter's placeholder.
- Installer text and icon: `windows/installer/oryon.iss`.
