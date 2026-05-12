# Northstar Labs — Self-Hosted F-Droid Publishing Guide
## Phone Repo (`/opt/appdata/fdroid`) · TV Repo (`/opt/appdata/fdroid-tv`)

---

## Overview

Every app publish is a three-part process:
1. **GitHub** — Source lives here. CI builds and signs the APK, then SSHs the APK to the server.
2. **Ubuntu-Services** — Server stores APKs in `repo/` and metadata in `metadata/`. `fdroid update` regenerates the index.
3. **Client devices** — Point to `https://<your-domain>/fdroid/repo` (phone) or `https://<your-domain>/fdroid-tv/repo` (TV).

---

## Part 1: One-Time Server Setup (already done, but documented here for rebuilds)

### 1.1 Install fdroidserver

```bash
sudo apt update
sudo apt install fdroidserver -y
# Verify
fdroid --version
```

### 1.2 Directory structure

```
/opt/appdata/fdroid/          ← phone repo root
  config.yml                  ← fdroidserver config
  keystore.jks                ← repo signing keystore
  repo/                       ← APKs + generated index files land here
  metadata/                   ← one .yml per app
  tmp/                        ← fdroidserver scratch space (auto-created)

/opt/appdata/fdroid-tv/       ← TV repo root (identical structure)
  config.yml
  keystore.jks
  repo/
  metadata/
```

### 1.3 Create the repo signing keystore (once per repo)

```bash
# Phone repo
cd /opt/appdata/fdroid
keytool -genkey -v \
  -keystore keystore.jks \
  -alias fdroid \
  -keyalg RSA -keysize 4096 \
  -validity 10000 \
  -storepass YOUR_STORE_PASS \
  -keypass YOUR_KEY_PASS \
  -dname "CN=Northstar Labs F-Droid, OU=, O=Northstar Labs, L=Dallas, ST=TX, C=US"

# TV repo (separate keystore)
cd /opt/appdata/fdroid-tv
keytool -genkey -v \
  -keystore keystore.jks \
  -alias fdroid \
  -keyalg RSA -keysize 4096 \
  -validity 10000 \
  -storepass YOUR_TV_STORE_PASS \
  -keypass YOUR_TV_KEY_PASS \
  -dname "CN=Northstar Labs F-Droid TV, OU=, O=Northstar Labs, L=Dallas, ST=TX, C=US"
```

### 1.4 config.yml (phone)

```yaml
# /opt/appdata/fdroid/config.yml
repo_url: "https://fdroid.northstarlabs.net/repo"
repo_name: "Northstar Labs"
repo_description: "Northstar Labs self-hosted app repository"
repo_icon: "icon.png"

keystore: "keystore.jks"
repo_keyalias: "fdroid"
keystorepass: "YOUR_STORE_PASS"
keypass: "YOUR_KEY_PASS"

identity_file: ""        # leave blank for local-only use
apksigner: ""            # auto-detected
```

### 1.4b config.yml (TV)

```yaml
# /opt/appdata/fdroid-tv/config.yml
repo_url: "https://fdroid-tv.northstarlabs.net/repo"
repo_name: "Northstar Labs TV"
repo_description: "Northstar Labs Fire TV / Android TV app repository"
repo_icon: "icon.png"

keystore: "keystore.jks"
repo_keyalias: "fdroid"
keystorepass: "YOUR_TV_STORE_PASS"
keypass: "YOUR_TV_KEY_PASS"
```

### 1.5 Initialize the repo (first time only)

```bash
cd /opt/appdata/fdroid
fdroid init        # only needed if repo/ doesn't exist yet

cd /opt/appdata/fdroid-tv
fdroid init
```

---

## Part 2: Per-App Setup (GitHub side)

### 2.1 GitHub repo structure for each app

```
northstar-works/<app-repo-name>/
  .github/
    workflows/
      build.yml              ← CI: build → sign → deploy
  app/
    src/
    build.gradle
  fdroid/
    metadata/
      <package.id>.yml       ← F-Droid metadata (copied to server on deploy)
  build.gradle
  settings.gradle
```

### 2.2 GitHub Secrets required (set per-repo under Settings → Secrets → Actions)

| Secret Name              | Value |
|--------------------------|-------|
| `KEYSTORE_BASE64`        | Base64-encoded release keystore JKS for the APP (not the fdroid repo key) |
| `KEY_ALIAS`              | Alias in the release keystore |
| `KEY_STORE_PASSWORD`     | Keystore password |
| `KEY_PASSWORD`           | Key password |
| `SSH_DEPLOY_KEY`         | Private key for SSH access to Ubuntu-Services |
| `SSH_HOST`               | IP or hostname of Ubuntu-Services |
| `SSH_USER`               | SSH username (e.g., `sid`) |
| `FDROID_REPO_PATH`       | `/opt/appdata/fdroid/repo` (phone) OR `/opt/appdata/fdroid-tv/repo` (TV) |
| `FDROID_META_PATH`       | `/opt/appdata/fdroid/metadata` (phone) OR `/opt/appdata/fdroid-tv/metadata` (TV) |
| `FDROID_ROOT_PATH`       | `/opt/appdata/fdroid` (phone) OR `/opt/appdata/fdroid-tv` (TV) |

**To generate `KEYSTORE_BASE64`:**
```bash
base64 -w 0 your-release-keystore.jks
# Paste the output as the secret value
```

**To generate `SSH_DEPLOY_KEY`:**
```bash
ssh-keygen -t ed25519 -C "github-actions-fdroid" -f ~/.ssh/github_fdroid_deploy
# Add ~/.ssh/github_fdroid_deploy.pub to ~/.ssh/authorized_keys on Ubuntu-Services
# Add the private key (~/.ssh/github_fdroid_deploy) as SSH_DEPLOY_KEY secret
```

---

## Part 3: F-Droid Metadata File (per app, lives in `fdroid/metadata/` in the repo)

### Template — Phone App

```yaml
# fdroid/metadata/com.yourpackage.id.yml

Categories:
  - System
License: Proprietary

AuthorName: Northstar Labs
AuthorWebSite: https://github.com/northstar-works

Name: Your App Name
Summary: One-line description of the app
Description: |
  Full description shown in the F-Droid client.
  Can be multi-line markdown-like text.

RepoType: git
Repo: https://github.com/northstar-works/<repo-name>

Builds:
  - versionName: '1.0.0'
    versionCode: 1
    commit: v1.0.0
    subdir: app
    gradle:
      - release

AutoUpdateMode: None
UpdateCheckMode: None

CurrentVersion: '1.0.0'
CurrentVersionCode: 1
```

### Template — TV App (add the TV-specific fields)

```yaml
# fdroid/metadata/com.yourpackage.id.yml

Categories:
  - Multimedia           # or System, Internet, etc.
License: Proprietary

AuthorName: Northstar Labs
AuthorWebSite: https://github.com/northstar-works

Name: Your TV App Name
Summary: One-line description
Description: |
  Full description.
  Designed for Amazon Fire TV and Android TV.

# TV-specific: mark it as a TV app
AntiFeatures: []

RepoType: git
Repo: https://github.com/northstar-works/<repo-name>

Builds:
  - versionName: '1.0.0'
    versionCode: 1
    commit: v1.0.0
    subdir: app
    gradle:
      - release

AutoUpdateMode: None
UpdateCheckMode: None

CurrentVersion: '1.0.0'
CurrentVersionCode: 1
```

> **Note:** For self-hosted repos, `Builds:` in the metadata is informational. You supply a pre-built, signed APK rather than having fdroidserver build from source. The `CurrentVersion` and `CurrentVersionCode` fields are what F-Droid clients display — **keep them in sync with your `build.gradle` versionCode/versionName**.

---

## Part 4: GitHub Actions `build.yml` Templates

### Template A — Phone App

```yaml
# .github/workflows/build.yml
name: Build & Deploy to F-Droid

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > app/release.jks

      - name: Build release APK
        run: |
          chmod +x gradlew
          ./gradlew assembleRelease \
            -Pandroid.injected.signing.store.file=${{ github.workspace }}/app/release.jks \
            -Pandroid.injected.signing.store.password="${{ secrets.KEY_STORE_PASSWORD }}" \
            -Pandroid.injected.signing.key.alias="${{ secrets.KEY_ALIAS }}" \
            -Pandroid.injected.signing.key.password="${{ secrets.KEY_PASSWORD }}"

      - name: Rename APK
        run: |
          APK_SRC=$(find app/build/outputs/apk/release -name "*.apk" | head -1)
          # Extract versionName from build.gradle for naming
          VERSION=$(grep versionName app/build.gradle | grep -oP '[\d.]+' | head -1)
          PKG=$(grep applicationId app/build.gradle | grep -oP '[\w.]+' | tail -1)
          DEST="${PKG}_${VERSION}.apk"
          cp "$APK_SRC" "$DEST"
          echo "APK_PATH=$DEST" >> $GITHUB_ENV
          echo "APK_NAME=$DEST" >> $GITHUB_ENV

      - name: Deploy APK to F-Droid repo
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_DEPLOY_KEY }}
          source: "${{ env.APK_PATH }}"
          target: "${{ secrets.FDROID_REPO_PATH }}"

      - name: Deploy metadata to server
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_DEPLOY_KEY }}
          source: "fdroid/metadata/*"
          target: "${{ secrets.FDROID_META_PATH }}"
          strip_components: 2

      - name: Run fdroid update on server
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_DEPLOY_KEY }}
          script: |
            cd ${{ secrets.FDROID_ROOT_PATH }}
            fdroid update --pretty --delete-unknown
            echo "F-Droid index updated successfully"
```

### Template B — TV App (identical structure, different secrets point to fdroid-tv paths)

```yaml
# .github/workflows/build.yml
name: Build & Deploy to F-Droid TV

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > app/release.jks

      - name: Build release APK
        run: |
          chmod +x gradlew
          ./gradlew assembleRelease \
            -Pandroid.injected.signing.store.file=${{ github.workspace }}/app/release.jks \
            -Pandroid.injected.signing.store.password="${{ secrets.KEY_STORE_PASSWORD }}" \
            -Pandroid.injected.signing.key.alias="${{ secrets.KEY_ALIAS }}" \
            -Pandroid.injected.signing.key.password="${{ secrets.KEY_PASSWORD }}"

      - name: Rename APK
        run: |
          APK_SRC=$(find app/build/outputs/apk/release -name "*.apk" | head -1)
          VERSION=$(grep versionName app/build.gradle | grep -oP '[\d.]+' | head -1)
          PKG=$(grep applicationId app/build.gradle | grep -oP '[\w.]+' | tail -1)
          DEST="${PKG}_${VERSION}.apk"
          cp "$APK_SRC" "$DEST"
          echo "APK_PATH=$DEST" >> $GITHUB_ENV

      - name: Deploy APK to F-Droid TV repo
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_DEPLOY_KEY }}
          source: "${{ env.APK_PATH }}"
          target: "${{ secrets.FDROID_REPO_PATH }}"    # points to fdroid-tv/repo

      - name: Deploy metadata to TV server
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_DEPLOY_KEY }}
          source: "fdroid/metadata/*"
          target: "${{ secrets.FDROID_META_PATH }}"    # points to fdroid-tv/metadata
          strip_components: 2

      - name: Run fdroid update on server (TV repo)
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_DEPLOY_KEY }}
          script: |
            cd ${{ secrets.FDROID_ROOT_PATH }}          # points to fdroid-tv/
            fdroid update --pretty --delete-unknown
            echo "F-Droid TV index updated successfully"
```

> **Key difference between phone and TV templates:** Only the GitHub Secrets differ — `FDROID_REPO_PATH`, `FDROID_META_PATH`, and `FDROID_ROOT_PATH` point to `fdroid-tv/` paths. The build steps are identical. This means you can also use a single workflow with an input parameter if you ever have a universal APK.

---

## Part 5: Step-by-Step Publish Checklist (Every New App)

### Step 1 — Create the GitHub repo

```
GitHub → northstar-works → New repository
Name: <app-repo-name>   (e.g., server-dashboard-android)
Visibility: Private (recommended for proprietary apps)
```

### Step 2 — Push source code

```bash
cd "C:\Users\Sidscri\Documents\GitHub\<app-folder>"
git init
git remote add origin https://github.com/northstar-works/<app-repo-name>.git
git add .
git commit -m "Initial commit v1.0.0"
git push -u origin main
```

### Step 3 — Create app release keystore (if not already done for this app)

```bash
# On Windows dev machine
keytool -genkey -v \
  -keystore app\release-keystore.jks \
  -alias <app-alias> \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -storepass YOUR_APP_STORE_PASS \
  -keypass YOUR_APP_KEY_PASS \
  -dname "CN=Northstar Labs, O=Northstar Labs, C=US"

# Convert to base64 for GitHub secret
certutil -encode app\release-keystore.jks app\release-keystore.b64
# Copy content of .b64 file (without header/footer lines) as KEYSTORE_BASE64
```

### Step 4 — Add GitHub Secrets

Go to: `https://github.com/northstar-works/<repo>/settings/secrets/actions`

Add all secrets from the table in Part 2. For phone apps set `FDROID_*` paths to `/opt/appdata/fdroid/...`, for TV apps use `/opt/appdata/fdroid-tv/...`.

### Step 5 — Create `fdroid/metadata/<package.id>.yml` in the repo

Use the template from Part 3. Fill in:
- `Name`, `Summary`, `Description`
- `CurrentVersion` = versionName from build.gradle
- `CurrentVersionCode` = versionCode from build.gradle
- `Repo` = GitHub URL

Commit and push.

### Step 6 — Tag the release to trigger CI

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions runs → builds APK → signs it → SCPs to server → runs `fdroid update`.

### Step 7 — Verify on the server

```bash
ssh sid@<ubuntu-services>
ls /opt/appdata/fdroid/repo/*.apk          # APK present?
cat /opt/appdata/fdroid/repo/index-v2.json | python3 -m json.tool | grep -A5 "com.your.package"
```

### Step 8 — Install on device

Open F-Droid → Repositories → verify your repo is listed → search for app name → Install.

---

## Part 6: Updating an Existing App

1. Bump `versionCode` and `versionName` in `app/build.gradle`
2. Update `CurrentVersion` and `CurrentVersionCode` in `fdroid/metadata/<pkg>.yml`
3. Commit, push, tag:
   ```bash
   git add .
   git commit -m "Release v1.0.7"
   git tag v1.0.7
   git push origin main --tags
   ```
4. CI runs automatically. Done.

> **Important:** `versionCode` must always strictly increase. F-Droid uses versionCode to determine update availability.

---

## Part 7: Manual Publish (Without CI)

If you need to push an APK manually (e.g., hotfix, testing):

```bash
# 1. Copy APK to server (from Windows, using the network share)
cp "path\to\app-release.apk" "\\sidscri-services\opt\appdata\fdroid\repo\com.sidscri.serverdashboardviewer_6.apk"

# 2. SSH into server and update index
ssh sid@sidscri-services
cd /opt/appdata/fdroid
fdroid update --pretty --delete-unknown

# Same for TV repo:
cd /opt/appdata/fdroid-tv
fdroid update --pretty --delete-unknown
```

---

## Part 8: Quick Reference — `fdroid update` Flags

| Flag | Purpose |
|------|---------|
| `--pretty` | Pretty-print JSON index files (easier to diff in git) |
| `--delete-unknown` | Remove APKs from the index that aren't in metadata |
| `--clean` | Full rebuild of index (slower, use after metadata changes) |
| `-v` | Verbose output |

---

## Part 9: Troubleshooting

| Problem | Fix |
|---------|-----|
| F-Droid client shows "Invalid index signature" | Run `fdroid update` again; check that `config.yml` keystore path is correct |
| APK not showing in client after update | Verify versionCode in metadata matches APK; run `fdroid update --clean` |
| SSH deploy step fails in CI | Check `SSH_DEPLOY_KEY` secret; ensure public key is in `~/.ssh/authorized_keys` on server |
| `fdroid update` exits with "no metadata" | Metadata .yml file missing from `/opt/appdata/fdroid/metadata/` |
| App shows wrong version name | `CurrentVersion` in metadata .yml is stale — update it and re-run `fdroid update` |
| "Unsigned APK rejected" | Your release APK wasn't signed — check keystore secrets in CI |
