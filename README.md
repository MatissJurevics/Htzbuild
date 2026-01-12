# Expo Remote Build Tool

This repository ships an executable CLI that can be installed globally or run via `npx` inside any project root. It wraps the Hetzner Cloud + EAS workflow from `build-remote.sh`, syncing the local project to a temporary Hetzner VM, running `eas build --local`, and downloading the Android artifact back to `build-output/`.

## Requirements

- Node.js 20 or newer (to run the CLI)
- `hcloud`, `ssh`, `scp`, `rsync`, and `git` installed in your PATH
- Hetzner API credentials (`HCLOUD_TOKEN`) or an active `hcloud` context
- Expo credentials (`EXPO_TOKEN`) if private credentials are required

## Installation

```bash
npm install -g /path/to/expobuildtool
```

Or run directly if you prefer not to install globally:

```bash
npx expobuild --profile preview
```

## Environment Setup (`.env` folder)

Every project that uses this CLI must expose its secrets under a `.env` directory at the project root. All files under that directory are parsed (sorted alphabetically) and merged into the process environment; you do not need to export them manually.

Example structure:

```
.env/
  credentials.env
  hcloud.env
  expo.env
```

Each file follows a standard dotenv format:

```
# .env/credentials.env
HCLOUD_TOKEN=sb_...
EXPO_TOKEN=eyJhbGciOi...
HETZNER_SSH_KEY=my-key
HETZNER_LOCATION=fsn1
HETZNER_SERVER_TYPE=cpx52
```

Use `--env-folder` if you keep your environment in a different location:

```
expobuild --env-folder config/env
```

## Usage

Run the CLI from the root of the project you want to build:

```bash
expobuild            # defaults to the preview profile
expobuild production # build with the production profile

expobuild -p preview
expobuild -e .env
expobuild --profile preview --env-folder .env
```

The CLI prints detailed status, waits for the Hetzner VM to become ready, syncs the project via `rsync`, executes `eas build --local` inside a `nohup` session, and polls the build logs until an artifact is ready. The downloaded artifact lands in `build-output/` with a timestamped filename.

## Verification

1. Ensure your `.env` folder is populated before running the CLI.
2. Verify that the Hetzner credentials are valid by running `hcloud context active` or `hcloud token list`.
3. After the CLI completes, confirm that `build-output/` contains the APK/AAB and inspect `build.log` on the remote server if you suspect issues (the CLI streams a portion of it during polling).

## Notes

- The `cloud-init-builder.yaml` in this repository installs Node.js 20, Java 17, Android SDK tools, and `eas-cli` on each Hetzner server.
- The CLI honors the same `HETZNER_*` variables from the original script for server type, location, and SSH key configuration.
- Cleanup hooks ensure the temporary VM is deleted if the process terminates unexpectedly.

