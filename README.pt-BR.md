# pr-panel

[English](README.md)

Indicador na barra superior para as suas pull requests abertas no GitHub. Num olhar você sabe se algum CI está falhando, rodando ou verde, e um clique lista todas as PRs para abrir no navegador.

```
● PRs 5 · 1 review
```

- A bolinha mostra o pior estado de CI entre as suas PRs abertas: **vermelha** se algum falhou, **amarela** se algum está rodando, **verde** se todos passaram.
- `· N review` aparece quando alguém pediu o seu review.
- O menu lista cada PR com a bolinha do CI, repositório, número, título e decisão de review ("aprovada", "pediram mudanças"), além das PRs esperando o seu review.

Hoje só o GNOME é suportado.

## Como funciona

```
timer systemd (3 min) ──▶ core/pr-panel-update ──gh api graphql──▶ GitHub
                                 │
                                 ▼
                 ~/.local/state/pr-panel/panel.json
                                 │  (monitor de arquivo)
                                 ▼
                       extensão do GNOME Shell
```

O script usa o login que você já tem no `gh` para buscar `author:@me` e `review-requested:@me`, então cada pessoa vê as próprias PRs sem configurar nada. A extensão nunca acessa a rede: ela só observa o arquivo JSON, o que mantém o GNOME Shell leve.

O CI é avaliado job a job, e não pelo resumo do GitHub. Um pipeline com mais jobs pulados do que aprovados aparece cinza ("pulado") em vez de verde, porque alguns repositórios usam um job de gate que pula o pipeline inteiro enquanto o GitHub continua mostrando sucesso.

## Requisitos

| | |
|---|---|
| Desktop | GNOME 45 ou mais novo, Wayland ou X11 (testado no GNOME 46 / Ubuntu 24.04) |
| GitHub CLI | [`gh`](https://cli.github.com/), logado com `gh auth login` |
| Outros | `/usr/bin/python3` (só biblioteca padrão), systemd de usuário |

## Instalação

```bash
git clone https://github.com/AbnerBittencourt/pr-panel.git
cd pr-panel
```

### Com o Claude Code

```bash
claude "/install-pr-panel"
```

O Claude roda as validações do ambiente, pede para você resolver o que faltar (ele nunca roda `sudo` nem mexe em tokens), instala tudo e compara a contagem de PRs com o GitHub. Depois de entrar de novo na sessão, rode `claude "/install-pr-panel verify"`.

### À mão

```bash
gh auth login              # se ainda não fez
gnome/install.sh --check   # só valida, não muda nada
gnome/install.sh           # valida e instala
```

Depois carregue a extensão:

- **Wayland:** faça logout e login. O GNOME só descobre extensões novas no login.
- **X11:** Alt+F2, digite `r`, Enter.

Por fim, confira se está tudo rodando:

```bash
gnome/install.sh --verify
```

### O que é instalado

| Caminho | O quê |
|---|---|
| `~/.local/share/gnome-shell/extensions/pr-panel@abnerbittencourt.github.io/` | a extensão |
| `~/.local/bin/pr-panel-update` | o script de atualização |
| `~/.config/systemd/user/pr-panel.{service,timer}` | atualização a cada 3 minutos |
| `~/.local/state/pr-panel/panel.json` | os dados que a extensão lê |

Rodar o instalador de novo é seguro e atualiza a cópia instalada.

## Desinstalar

```bash
gnome/uninstall.sh
```

O login do `gh` não é tocado.

## Problemas comuns

**O indicador não aparece.** No Wayland, confira se você fez logout depois de instalar. Depois rode `gnome/install.sh --verify`; se a extensão aparece mas não está ativa, veja `journalctl --user -b | grep pr-panel`.

**Faltam PRs de uma organização.** Organizações com SAML SSO exigem autorizar o token do `gh`. Rode `~/.local/bin/pr-panel-update` para ver o erro, depois `gh auth refresh -h github.com -s read:org` e autorize o token para a organização em <https://github.com/settings/tokens>. As PRs das outras organizações continuam aparecendo enquanto isso.

**O menu mostra "Atualizado às" com um horário antigo.** O script está falhando. Veja `journalctl --user -u pr-panel`.

**Só 50 PRs.** O script busca até 50 PRs abertas e 50 pedidos de review.

**Clicar numa PR não faz nada.** Só links `https://github.com/` são abertos, então o GitHub Enterprise Server ainda não é suportado.

## Privacidade

Nada sai da sua máquina além das consultas GraphQL que o `gh` envia ao GitHub. Este projeto não guarda token nenhum: ele usa o armazenamento de credenciais do próprio `gh`. O `panel.json` tem títulos de PRs privadas, por isso é gravado com permissão `0600` dentro de uma pasta `0700`.

## Estrutura do repositório

```
core/pr-panel-update     script de atualização, independente de plataforma (Python + gh)
gnome/extension/         extensão do GNOME Shell
gnome/install.sh         valida, instala e verifica
gnome/uninstall.sh       remove tudo
.claude/commands/        comando de instalação do Claude Code
```

Uma versão para a barra de menus do macOS está planejada em `macos/`, reaproveitando o `core/`.

## Licença

[MIT](LICENSE)
