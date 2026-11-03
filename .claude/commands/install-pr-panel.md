---
description: Install and validate the GitHub PR indicator for the GNOME top bar
allowed-tools: Bash(gnome/install.sh:*), Bash(gh auth status), Bash(gnome-shell --version)
---

Install the PR indicator from this repository on the user's machine. Reply in the user's language, in short sentences.

What gets installed: the GNOME extension in `gnome/extension/`, the `core/pr-panel-update` script (queries GitHub through `gh` and writes `~/.local/state/pr-panel/panel.json`) and a 3-minute systemd user timer. It uses no token of its own and sends data nowhere except GitHub.

Only GNOME is supported today. If the user is on macOS or another desktop, say so and stop.

## Rules

- Never run `sudo` yourself or ask for a password in chat. When it is needed, ask the user to run the command prefixed with `!`, e.g. `! sudo apt install gh`.
- Never print, read or ask for tokens. `gh auth login` is interactive: ask the user to run `! gh auth login`.
- Do not edit the installer, the extension or any GNOME setting beyond what `gnome/install.sh` already does. If something does not fit, stop and explain.

## Steps

1. Run `gnome/install.sh --check` and read every line.
2. Resolve each `FAIL`, then run the check again:

   | FAIL | What to do |
   |---|---|
   | desktop is not GNOME, or `gnome-shell` missing | Stop. The indicator only works on GNOME. |
   | gnome-shell older than 45 | Stop. The extension uses ES modules, available from GNOME 45 on. |
   | session not detected | Probably SSH or a TTY. Ask the user to run `claude` from a terminal inside the graphical session. |
   | `gh` missing | Ask the user to install it: Ubuntu/Debian `! sudo apt install gh`, Fedora `! sudo dnf install gh`, Arch `! sudo pacman -S github-cli`. |
   | `gh` not logged in | Ask for `! gh auth login`. |
   | `gnome-extensions` or `gsettings` missing | They ship with GNOME itself; the GNOME install is incomplete. Stop and explain. |
   | `/usr/bin/python3` missing | Ask the user to install the `python3` package. |
   | user extensions disabled | Explain it and, with the user's OK, run `gsettings set org.gnome.shell disable-user-extensions false`. |
   | systemd user instance unavailable | Stop and explain; the timer depends on it. |

3. With a clean check, run `gnome/install.sh`.
4. If it prints `AVISO primeira atualização falhou`, find out why with `~/.local/bin/pr-panel-update`. On a SAML/SSO message, ask for `! gh auth refresh -h github.com -s read:org` and explain the organization may require authorizing the token at github.com/settings/tokens. Run it again.
5. Report how many PRs landed in `~/.local/state/pr-panel/panel.json` and compare with `gh search prs --author=@me --state=open --limit 50 --json number --jq length`. If the numbers differ, investigate before moving on.
6. If gnome-shell is not version 46, warn that this version has not been tested.
7. Finish by telling the user exactly how to load the extension: on Wayland, log out and back in; on X11, Alt+F2, `r`, Enter. Remind them to save open work before logging out, and that afterwards they only need to run `claude "/install-pr-panel verify"` in this folder.

## If the argument is "verify"

Argument received: $ARGUMENTS

Skip the steps above. Run `gnome/install.sh --verify`, explain each `FAIL` and describe what should show in the top bar: `● PRs N`, with a red dot if any CI failed, yellow if any is running, green if all passed. Ask whether the dot shows in color. To uninstall: `gnome/uninstall.sh`.
