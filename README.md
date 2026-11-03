# pr-panel

[Português](README.pt-BR.md)

A top-bar indicator for your open GitHub pull requests. One glance tells you whether any CI is failing, still running or green, and a click lists every PR so you can open it in the browser.

```
● PRs 5 · 1 review
```

- The dot shows the worst CI state across your open PRs: **red** if any failed, **yellow** if any is running, **green** if all passed.
- `· N review` appears when someone has requested your review.
- The menu lists each PR with its CI dot, repository, number, title and review decision ("aprovada", "pediram mudanças"), plus the PRs waiting for your review.

Only GNOME is supported today. The interface text is in Portuguese.

## How it works

```
systemd timer (3 min) ──▶ core/pr-panel-update ──gh api graphql──▶ GitHub
                                 │
                                 ▼
                 ~/.local/state/pr-panel/panel.json
                                 │  (file monitor)
                                 ▼
                       GNOME Shell extension
```

The updater uses your existing `gh` login to search `author:@me` and `review-requested:@me`, so each person sees their own PRs with no configuration. The extension never talks to the network: it only watches the JSON file, which keeps GNOME Shell light.

CI is judged per job rather than from GitHub's summary. A pipeline where more jobs were skipped than passed shows as grey ("skipped") instead of green, because some repositories use a gate job that skips the whole pipeline while GitHub still reports success.

## Requirements

| | |
|---|---|
| Desktop | GNOME 45 or newer, Wayland or X11 (tested on GNOME 46 / Ubuntu 24.04) |
| GitHub CLI | [`gh`](https://cli.github.com/), logged in with `gh auth login` |
| Other | `/usr/bin/python3` (standard library only), systemd user instance |

## Installation

```bash
git clone https://github.com/AbnerBittencourt/pr-panel.git
cd pr-panel
```

### With Claude Code

```bash
claude "/install-pr-panel"
```

Claude runs the environment checks, asks you to fix whatever is missing (it never runs `sudo` or handles tokens itself), installs everything and compares the PR count against GitHub. After logging back in, run `claude "/install-pr-panel verify"`.

### Manually

```bash
gh auth login              # if you haven't yet
gnome/install.sh --check   # validate only, changes nothing
gnome/install.sh           # validate and install
```

Then load the extension:

- **Wayland:** log out and back in. GNOME only discovers new extensions at login.
- **X11:** press Alt+F2, type `r`, press Enter.

Finally, confirm everything is running:

```bash
gnome/install.sh --verify
```

### What gets installed

| Path | What |
|---|---|
| `~/.local/share/gnome-shell/extensions/pr-panel@abnerbittencourt.github.io/` | the extension |
| `~/.local/bin/pr-panel-update` | the updater |
| `~/.config/systemd/user/pr-panel.{service,timer}` | refresh every 3 minutes |
| `~/.local/state/pr-panel/panel.json` | the data the extension reads |

Running the installer again is safe and updates the installed copy.

## Uninstall

```bash
gnome/uninstall.sh
```

Your `gh` login is left untouched.

## Troubleshooting

**The indicator doesn't show up.** On Wayland, make sure you logged out after installing. Then run `gnome/install.sh --verify`; if the extension is listed but not active, check `journalctl --user -b | grep pr-panel`.

**PRs from an organization are missing.** Organizations with SAML SSO require authorizing the `gh` token. Run `~/.local/bin/pr-panel-update` to see the error, then `gh auth refresh -h github.com -s read:org` and authorize the token for that organization at <https://github.com/settings/tokens>. PRs from other organizations keep showing in the meantime.

**The menu says "Atualizado às" an old time.** The updater is failing. See `journalctl --user -u pr-panel`.

**Only 50 PRs.** The updater fetches up to 50 open PRs and 50 review requests.

## Privacy

Nothing leaves your machine except the GraphQL queries `gh` sends to GitHub. No token is stored by this project: it relies on `gh`'s own credential storage.

## Repository layout

```
core/pr-panel-update     platform-independent updater (Python + gh)
gnome/extension/         GNOME Shell extension
gnome/install.sh         checks, installs and verifies
gnome/uninstall.sh       removes everything
.claude/commands/        Claude Code install command
```

A macOS menu bar version is planned under `macos/`, reusing `core/`.

## License

[MIT](LICENSE)
