# CachyOS DMS AI Session Manager

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) widget for independent AI coding sessions on CachyOS and other Arch-based systems.

It provides two isolated Codex profiles and one Antigravity profile by default. It keeps authentication in the official CLIs: this plugin never reads, copies, or stores credentials.

## Features

- Two separate `CODEX_HOME` directories, with individual names and logins.
- One Antigravity (`agy`) session.
- Codex plan, session and weekly limits, reset countdowns, and every available reset credit.
- Antigravity quota collection from its authenticated local language server.
- Provider selector, account switcher, and a settings action for logins and names.
- Cached usage data: the bar and popout open without waiting for provider requests.

## Requirements

- DankMaterialShell 1.6 or newer.
- Ghostty for login and terminal launches.
- Codex CLI for Codex profiles.
- Antigravity CLI (`agy`) for the Antigravity profile.

## Install

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
git clone https://github.com/Cykes95/cachyos-dms-ai-session-manager.git \
  ~/.config/DankMaterialShell/plugins/AiSessionManager
dms ipc call plugin-scan scan
dms ipc call plugins enable aiSessionManager
```

Add `aiSessionManager` to a DankBar widget section from DMS Settings, then restart DMS if it is not shown immediately.

## Usage

Click the bar widget to view usage. Use the gear icon in the panel header to rename profiles or start the official CLI login. Select a Codex account with the account switcher; new terminal sessions use that profile.

Antigravity usage is available while Antigravity is running and its local language server is authenticated. The widget refreshes after launching it and periodically thereafter.

## Data locations

- Profile metadata: `~/.config/ai-session-manager/sessions.json`
- Isolated Codex homes and usage cache: `~/.local/share/ai-session-manager/`

Both locations are created with user-only permissions.

## Provider marks

The Antigravity icon is downloaded from the official Antigravity brand assets. The OpenAI mark comes from the locally installed official ChatGPT application. All product marks belong to their respective owners.

## License

MIT. Provider marks are excluded from the license and remain subject to their owners' terms.
