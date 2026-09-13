# CachyOS DMS AI Session Manager

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) widget for independent AI coding sessions on CachyOS and other Arch-based systems.

It provides two isolated Codex profiles and one Antigravity profile by default. It keeps authentication in the official CLIs: this plugin never reads, copies, or stores credentials.

## Features

- Two separate `CODEX_HOME` directories, with individual names and logins.
- Automatic active profile symlinking (`~/.local/share/ai-session-manager/codex/current`) and CLI wrapper (`~/.local/bin/codex`) so any open terminal automatically runs the selected Codex account.
- Direct Terminal launcher button in popout header and middle-click on the bar pill.
- One Antigravity (`agy`) session.
- Codex plan, session and weekly limits, reset countdowns, and every available reset credit.
- Antigravity quota collection from its authenticated local language server, with a clearly marked cached snapshot while it is closed.
- Modern rounded design with pill-shaped buttons, account selector cards, and thick progress indicators.
- Cached usage data and instant manual refresh button in popout header.

## Requirements

- DankMaterialShell 1.6 or newer.
- Ghostty for login and terminal launches.
- Codex CLI (`chatgpt-desktop-bin` on Arch/CachyOS).
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

Click the bar widget to view usage or middle-click it to launch the active profile in your terminal. Use the gear icon in the panel header to rename profiles or start the official CLI login. Select a Codex account with the account cards; new and existing terminal sessions automatically use that profile.

Antigravity usage runs its native `/usage` command in non-interactive JSON mode, so it returns the same Gemini and Claude/GPT Session + Weekly windows without opening a terminal or starting an agent turn. The widget falls back to the local language server and then agy's official OAuth session if needed. The plugin does not create or store a second copy of the credential. If the session expires, use the Login action once to renew it. When a refresh is unavailable, the widget keeps the last successful reading and labels it `SIN CONEXIÓN` with its age; it does not present cached data as live.

## Data locations

- Profile metadata: `~/.config/ai-session-manager/sessions.json`
- Isolated Codex homes and usage cache: `~/.local/share/ai-session-manager/`
- Active profile symlink: `~/.local/share/ai-session-manager/codex/current`
- Dynamic Codex CLI wrapper: `~/.local/bin/codex`

## Provider marks

The Antigravity icon is downloaded from the official Antigravity brand assets. The OpenAI mark comes from the locally installed official ChatGPT application. All product marks belong to their respective owners.

## License

MIT. Provider marks are excluded from the license and remain subject to their owners' terms.
