#!/usr/bin/env bash
# Remove tudo que o install.sh criou. O login do gh não é tocado.
UUID=pr-panel@abnerbittencourt.github.io
systemctl --user disable --now pr-panel.timer 2>/dev/null
rm -f ~/.config/systemd/user/pr-panel.service ~/.config/systemd/user/pr-panel.timer ~/.local/bin/pr-panel-update
systemctl --user daemon-reload
gnome-extensions disable "$UUID" 2>/dev/null
python3 - "$UUID" <<'PY'
import ast, subprocess, sys
current = subprocess.check_output(["gsettings", "get", "org.gnome.shell", "enabled-extensions"], text=True).removeprefix("@as ")
subprocess.run(["gsettings", "set", "org.gnome.shell", "enabled-extensions",
                str([e for e in ast.literal_eval(current) if e != sys.argv[1]])], check=True)
PY
rm -rf ~/.local/share/gnome-shell/extensions/"$UUID" "${XDG_STATE_HOME:-$HOME/.local/state}/pr-panel"
echo "Removido. O indicador some do painel no próximo login."
