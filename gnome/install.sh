#!/usr/bin/env bash
# gnome/install.sh           valida o ambiente e instala
# gnome/install.sh --check   só valida, sem mudar nada
# gnome/install.sh --verify  confere a instalação depois do login
set -u
cd "$(dirname "$(readlink -f "$0")")"

UUID=pr-panel@abnerbittencourt.github.io
EXT_DIR=$HOME/.local/share/gnome-shell/extensions/$UUID
BIN=$HOME/.local/bin/pr-panel-update
UNITS=$HOME/.config/systemd/user
PANEL=${XDG_STATE_HOME:-$HOME/.local/state}/pr-panel/panel.json
failed=0

ok() { echo "OK    $1"; }
fail() { echo "FAIL  $1"; failed=1; }

shell_major() { gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1; }

check() {
  [[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* ]] && ok "desktop GNOME (${XDG_CURRENT_DESKTOP})" || fail "desktop: GNOME necessário, encontrado '${XDG_CURRENT_DESKTOP:-nenhum}'"
  local major; major=$(shell_major)
  if [[ -z $major ]]; then fail "gnome-shell não encontrado"
  elif (( major < 45 )); then fail "gnome-shell $major: precisa ser 45 ou mais novo"
  elif (( major == 46 )); then ok "gnome-shell $major (versão testada)"
  else ok "gnome-shell $major (funciona em tese, não testado nessa versão)"; fi
  case ${XDG_SESSION_TYPE:-} in
    wayland|x11) ok "sessão ${XDG_SESSION_TYPE}" ;;
    *) fail "sessão gráfica não detectada (XDG_SESSION_TYPE='${XDG_SESSION_TYPE:-}')" ;;
  esac
  [[ -x /usr/bin/python3 ]] && ok "python3" || fail "/usr/bin/python3 ausente"
  for tool in gnome-extensions gsettings; do
    command -v "$tool" >/dev/null && ok "$tool" || fail "$tool ausente"
  done
  systemctl --user is-system-running >/dev/null 2>&1; [[ $? -ne 127 ]] && systemctl --user show-environment >/dev/null 2>&1 \
    && ok "systemd do usuário" || fail "systemd do usuário indisponível"
  [[ $(gsettings get org.gnome.shell disable-user-extensions 2>/dev/null) == true ]] \
    && fail "extensões de usuário desligadas (disable-user-extensions=true)" || ok "extensões de usuário permitidas"
  if ! command -v gh >/dev/null; then fail "gh (GitHub CLI) ausente"
  elif ! gh auth status >/dev/null 2>&1; then fail "gh sem login: rode gh auth login"
  else ok "gh logado como $(gh api user --jq .login 2>/dev/null)"; fi
}

install_all() {
  local major gh_dir; major=$(shell_major)
  # Caminho absoluto, com % escapado: o systemd trata % como especificador no arquivo da unidade.
  gh_dir=$(cd "$(dirname "$(command -v gh)")" && pwd); gh_dir=${gh_dir//%/%%}
  mkdir -p "$EXT_DIR" "$UNITS" "$(dirname "$BIN")"
  cp extension/extension.js "$EXT_DIR/"
  python3 - "$major" extension/metadata.json "$EXT_DIR/metadata.json" <<'PY'
import json, sys
major, source, target = sys.argv[1:]
metadata = json.load(open(source))
metadata["shell-version"] = sorted({*metadata["shell-version"], major})
json.dump(metadata, open(target, "w"), ensure_ascii=False, indent=2)
PY
  install -m 755 ../core/pr-panel-update "$BIN"
  cat > "$UNITS/pr-panel.service" <<UNIT
[Unit]
Description=Atualiza o resumo de PRs do painel

[Service]
Type=oneshot
Environment="PATH=$gh_dir:/usr/local/bin:/usr/bin:/bin"
ExecStart=%h/.local/bin/pr-panel-update
UNIT
  cat > "$UNITS/pr-panel.timer" <<UNIT
[Unit]
Description=Atualiza as PRs do painel a cada 3 minutos

[Timer]
OnStartupSec=30s
OnUnitActiveSec=3min

[Install]
WantedBy=timers.target
UNIT
  systemctl --user daemon-reload
  systemctl --user enable --now pr-panel.timer
  "$BIN" || echo "AVISO primeira atualização falhou; veja journalctl --user -u pr-panel"
  # gnome-extensions enable recusa extensão que o Shell ainda não conhece; a lista vale no próximo login.
  python3 - "$UUID" <<'PY'
import ast, subprocess, sys
uuid = sys.argv[1]
def get(key):
    return ast.literal_eval(subprocess.check_output(["gsettings", "get", "org.gnome.shell", key], text=True).removeprefix("@as "))
def put(key, value):
    subprocess.run(["gsettings", "set", "org.gnome.shell", key, str(value)], check=True)
put("enabled-extensions", sorted({*get("enabled-extensions"), uuid}))
put("disabled-extensions", [e for e in get("disabled-extensions") if e != uuid])
PY
  echo
  if [[ ${XDG_SESSION_TYPE:-} == x11 ]]; then
    echo "PRONTO. Para carregar: Alt+F2, digite r, Enter. Depois rode gnome/install.sh --verify"
  else
    echo "PRONTO. Wayland só carrega extensão nova no login: faça logout e login, depois rode gnome/install.sh --verify"
  fi
}

verify() {
  systemctl --user is-active pr-panel.timer >/dev/null && ok "timer ativo" || fail "timer inativo"
  "$BIN" && ok "pr-panel-update rodou" || fail "pr-panel-update falhou"
  if [[ -f $PANEL ]]; then
    ok "painel: $(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(len(d['mine']),'PRs abertas,',len(d['requested']),'reviews pedidos, atualizado às',d['updated'])" "$PANEL")"
  else fail "panel.json não existe"; fi
  local state; state=$(gnome-extensions info "$UUID" 2>/dev/null | grep -oE 'State: .*' )
  [[ $state == *ACTIVE* ]] && ok "extensão ativa" || fail "extensão: ${state:-não encontrada pelo Shell (falta logout?)}"
  local errors; errors=$(journalctl --user -b --no-pager 2>/dev/null | grep -i "$UUID" | grep -iE 'error|exception' | tail -3)
  [[ -z $errors ]] && ok "sem erros no log" || fail "erros no log: $errors"
}

case ${1:-} in
  --check) check ;;
  --verify) verify ;;
  "") check; if (( failed )); then echo; echo "Nada foi instalado: resolva os FAIL acima."; exit 1; fi; install_all ;;
  *) echo "uso: gnome/install.sh [--check|--verify]"; exit 2 ;;
esac
exit $failed
