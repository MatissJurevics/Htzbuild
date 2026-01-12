# htzbuild 🚀

> **Thunderously Fast EAS Remote Builds on Hetzner Cloud**

[![npm version](https://img.shields.io/npm/v/htzbuild.svg)](https://www.npmjs.com/package/htzbuild)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**htzbuild** is a high-performance CLI tool that supercharges your Expo development workflow. It spins up a powerful, ephemeral dedicated server on Hetzner Cloud, syncs your project, runs `eas build --local`, and brings the artifact right back to your machine—often significantly faster and cheaper than standard cloud build options.

---

## ✨ Features

- **🚀 High Performance**: Defaults to `cpx52` (AMD EPYC) compilation power.
- **☁️ Ephemeral**: Automatically spins up and tears down VMs for each build.
- **🔒 Secure**: Syncs environment variables and credentials securely via SSH.
- **🛠️ Configurable**: Supports custom build profiles, environments, and sync rules.
- **📦 Local-Compatible**: Uses `eas build --local` remotely vs. hosted CI services.

---

## 🛠 Prerequisites

- **Node.js** (v20 or newer)
- **Hetzner Cloud Account**: API Token (`HCLOUD_TOKEN`).
- **Tools**: `ssh`, `scp`, `rsync`, `git` (in your system PATH).
- **Expo**: An Expo project with EAS configured.

---

## 📦 Installation

To use `htzbuild` anywhere:

```bash
npm install -g htzbuild
```

Or run it directly with `npx` (no installation required):

```bash
npx htzbuild --help
```

---

## 🚀 Quick Start

1.  **Set up your environment**:
    Create a `.env` directory in your project root and add your secrets.

    ```bash
    mkdir .env
    echo "HCLOUD_TOKEN=your_token_here" > .env/hcloud.env
    echo "EXPO_TOKEN=your_expo_token" > .env/expo.env
    ```

    > **Note**: You can also use `htzbuild config` to save Hetzner credentials globally so you don't need them in every project.

2.  **Run a build**:

    ```bash
    htzbuild --profile preview
    ```

    Sit back while `htzbuild` provisions a server, builds your app, and downloads the APK/AAB to `./build-output`.

---

## ⚙️ Configuration

### Environment Variables (`.env/`)

`htzbuild` automatically loads all files in the `.env/` directory at your project root.

**Minimum required variables:**
- `HCLOUD_TOKEN`: Your Hetzner Cloud API token.
- `EXPO_TOKEN`: (Optional but recommended) For authenticating EAS on the remote builder.

**Optional customizations:**
- `HETZNER_LOCATION`: Data center location (default: `fsn1`).
- `HETZNER_SERVER_TYPE`: Server flavor (default: `cpx52`).
- `HETZNER_SSH_KEY`: Name of the SSH key to inject (if pre-configured in Hetzner).

### Config File (`htzbuild.config.json`)

For advanced control, place a `htzbuild.config.json` in your project root.

```json
{
  "remoteProjectDir": "project",
  "artifactForProfile": {
    "preview": "build-output/app-release.apk",
    "production": "build-output/app-release.aab"
  },
  "syncExcludes": [
    ".git",
    "node_modules",
    "dist"
  ]
}
```

### Global Config

Configure defaults globally to avoid repeating flags:

```bash
htzbuild config --token <HCLOUD_TOKEN> --ssh-key <KEY_NAME>
```

Credentials are saved in `~/.config/htzbuild/credentials.json`.

---

## ❓ Troubleshooting

**SSH Authentication Failures**
- Ensure your local SSH agent is running (`ssh-add -l`).
- `htzbuild` attempts to reuse existing Hetzner SSH keys if specified; otherwise, it relies on your local default keys.

**Build Failures**
- Check the `build.log` streamed during execution.
- If the server terminates too early, try running with `--keep-alive-on-error` to debug the running VM.

---

## 📄 License

MIT © [Matiss Jurevics](https://github.com/MatissJurevics)
