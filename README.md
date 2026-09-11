# Dotfiles LuHer

Configuración para macOS y Linux con zsh, Ghostty, Starship, OpenCode y un multiplexor de terminal. `install.sh` es el instalador heredado de enlaces solamente; `./dotfiles setup` puede instalar aplicaciones después de una confirmación explícita.

## Instalación rápida

La CLI siempre muestra un plan de aplicaciones y configuraciones antes de aplicar cambios. Empiece con una vista previa y ejecute la instalación real solo después de revisarla:

```bash
./dotfiles setup --dry-run
# Revise el plan; después, si lo aprueba:
./dotfiles setup
```

`--select` es opcional y evita el selector visual; `--configs-only` omite la fase de aplicaciones y enlaza solamente las configuraciones seleccionadas:

```bash
./dotfiles setup --select tmux,starship --dry-run
./dotfiles setup --select tmux,starship --yes --configs-only
```

Sin `--select`, `./dotfiles setup` ofrece un selector visual únicamente en una terminal: 15 componentes en macOS y 14 en Linux. Use las flechas para mover el foco, `Espacio` para marcar y `Enter` para confirmar; al no caber todas las filas, el foco desplaza la vista y el estado muestra el rango visible. El selector empieza vacío; `Enter` sin opciones, `Esc`, `Ctrl-C` o EOF cancelan sin cambios. La UI entrega internamente una lista CSV a Bash. Si existe `tui/bin/dotfiles-tui`, usa la interfaz Bubble Tea; si no existe, usa el selector Python. También puede elegir un binario ya compilado con `DOTFILES_TUI_BIN=/ruta/dotfiles-tui`; una ruta explícita que no sea ejecutable falla claramente y no cambia al selector Python. `--select` siempre evita cualquier UI. Con `TERM=dumb`, `TERM` sin definir o una terminal estrecha se usa una lista numerada sin secuencias de control; `NO_COLOR` desactiva el color. Sin `--yes`, la confirmación es explícita y por defecto se cancela; `--dry-run` nunca crea archivos, compila la TUI ni ejecuta gestores. AeroSpace aparece y se acepta solo en macOS. Ghostty en Debian/Ubuntu (incluido antes de 26.04) requiere instalación manual posterior; no se usa ningún instalador comunitario.

### Selector Bubble Tea opcional

La TUI Go es un módulo aislado en `tui/` y requiere Go `>=1.24`. Para usarla, compile explícitamente el binario; la primera compilación puede necesitar red para descargar y verificar las dependencias de Go:

```bash
cd tui && go build -o bin/dotfiles-tui .
```

`./dotfiles setup` no compila la TUI ni descarga sus dependencias automáticamente: sin ese binario conserva el selector Python. El binario local `tui/bin/` está ignorado por Git. La cabecera azul se adapta a terminales claras u oscuras, conserva el icono `>_` y `Dotfiles · LuHer`, se compacta cuando hace falta y desplaza las filas para mantener visible la opción enfocada.

Para probar únicamente la TUI con dependencias ya presentes en caché:

```bash
cd tui && GOPROXY=off GOTOOLCHAIN=local GOWORK=off go test ./...
bash tests/test_tui.sh tui/bin/dotfiles-tui
```

`./scripts/check.sh` no construye ni descarga Go; `shellcheck` también es opcional y se omite si no está disponible. Para incluir de forma explícita las pruebas Go que usan solo la caché, compile primero el binario y ejecute `DOTFILES_CHECK_TUI=1 ./scripts/check.sh`.

La fase de aplicaciones instala solo después de la confirmación explícita. Use `--configs-only` para omitirlas; con `--configs-only --select pi`, se configura Pi pero no se ejecuta el gestor de aplicaciones ni el enlazador de dotfiles. Para Pi, añada `pi` y elija explícitamente `--pi-merge` cuando exista una configuración previa; el selector no infiere esa opción. Sin ella se usa el modo nuevo de `scripts/setup-pi.sh`. En Linux, Herdr y Starship usan sus instaladores oficiales descargados por HTTPS, después de mostrar la URL, destino local y riesgo de ejecutar código remoto. La confirmación explícita de cada script es independiente; `--yes` por sí solo nunca autoriza instaladores remotos. Para automatización no interactiva use `--yes --allow-remote-installers` solo después de revisar el riesgo. Se requiere `~/.local/bin` escribible y no se modifica automáticamente el PATH. El script aprobado se ejecuta con los privilegios de su usuario y no está aislado: sus descargas posteriores quedan bajo control del script oficial. En la fuente obtenida, Herdr valida el SHA-256 del binario contra un manifiesto también descargado, no una suma fijada independientemente; Starship no ofrece una verificación de integridad equivalente. Por tanto, la descarga inicial restringida a HTTPS no constituye una garantía global de HTTPS ni de integridad para las acciones posteriores. Ghostty requiere Ubuntu >=26.04 para apt; en Debian o Ubuntu anterior se detiene con guía manual. Consulte las fuentes oficiales: [Herdr](https://herdr.dev/docs/install/) y [Starship](https://starship.rs/guide/).

### Herramientas de shell en selector y CLI

El selector visual y `--select` ofrecen siete herramientas ya referenciadas por la configuración: `atuin`, `zoxide`, `eza`, `fnm`, `zsh-autosuggestions`, `zsh-syntax-highlighting` y `neovim`. Las filas usan nombres descriptivos en español, como **Autosugerencias Zsh**, **Resaltado Zsh** y **Neovim**; `neovim` sigue siendo el ID estable y la comprobación posterior exige el ejecutable `nvim`.

```bash
# Solo instala la aplicación; no ejecuta install.sh ni crea enlaces.
./dotfiles setup --select eza --yes

# Instala ambas aplicaciones, pero enlaza únicamente tmux.
./dotfiles setup --select tmux,eza --yes
```

`--configs-only` omite las siete herramientas. Una selección que contenga solamente una de ellas con esa opción falla de forma explícita, para no simular una instalación ni enlazar una configuración vacía. La activación de las integraciones de zsh sigue siendo independiente: enlace o despliegue `zsh` mediante una selección separada si todavía no está instalado; esta etapa nunca reescribe `.zshrc`.

| ID | Propósito | macOS (Homebrew existente) | Linux Debian/Ubuntu |
| --- | --- | --- | --- |
| `atuin` | Historial de shell | `brew install atuin` | `cargo install --locked --root "$HOME/.local" atuin`; requiere Cargo y `rustc >=1.98.0` |
| `zoxide` | Navegación entre directorios | `brew install zoxide` | consulta `apt-cache policy zoxide`; usa el paquete nativo solo con `Candidate`, o `cargo install --locked --root "$HOME/.local" zoxide` si no existe |
| `eza` | Listado moderno de archivos | `brew install eza` | `cargo install --locked --root "$HOME/.local" eza`; no agrega el repositorio externo de eza |
| `fnm` | Gestor de versiones de Node.js | `brew install fnm` | `cargo install --locked --root "$HOME/.local" fnm`; no ejecuta el instalador remoto de fnm ni instala Node.js |
| `zsh-autosuggestions` | Sugerencias mientras escribe en Zsh | `brew install zsh-autosuggestions` | consulta `apt-cache policy`; usa el paquete nativo solo con `Candidate` |
| `zsh-syntax-highlighting` | Resaltado de sintaxis en Zsh | `brew install zsh-syntax-highlighting` | consulta `apt-cache policy`; usa el paquete nativo solo con `Candidate` |
| `neovim` | Editor extensible (`nvim`) | `brew install neovim` | consulta `apt-cache policy neovim`; usa el paquete nativo solo con `Candidate` |

El `dry-run` solo muestra rutas condicionales: no llama a Homebrew, Cargo, `apt-cache`, red ni escribe archivos. Tras `--yes`, las comprobaciones de prerrequisitos, seguridad de `~/.local` y candidatos terminan antes de la primera instalación. Las aplicaciones que ya están instaladas se omiten; esta CLI no las actualiza. Las rutas Cargo usan explícitamente [`--root`](https://doc.rust-lang.org/cargo/commands/cargo-install.html#option-cargo-install---root) `"$HOME/.local"` y requieren una herramienta Cargo/Rust ya instalada (`atuin` exige además `rustc >=1.98.0`). Verifican los ejecutables en `~/.local/bin`, no sobrescriben `CARGO_HOME` ni `CARGO_INSTALL_ROOT`, y no instalan Rust/rustup automáticamente. Cargo puede descargar y compilar código de terceros. Los plugins se consideran instalados solo si existe un archivo fuente legible en las rutas que usa zsh, no mediante `command -v`; en macOS la detección también consulta `brew --prefix` para no fijar el prefijo de un usuario. No se usan `setup.atuin.sh`, importación ni sincronización de historial de Atuin, cuentas, ni instaladores remotos de fnm.

La instalación no modifica `PATH`, el shell ni los archivos de inicio. Una herramienta en `~/.local/bin` puede estar instalada y no estar disponible en el shell actual. Una selección que solo contiene herramientas no enlaza `zsh` automáticamente ni reescribe `.zshrc`: seleccione `zsh` por separado si quiere enlazar esa configuración. La `.zshrc` de este repositorio añade esa ruta después de comprobar las integraciones opcionales, por lo que esta etapa no promete activación en el mismo shell ni en la primera carga si la ruta no estaba ya presente. Configure o exporte el `PATH` por separado antes de recargar zsh.

Métodos y limitaciones proceden de las fuentes oficiales: [Atuin](https://docs.atuin.sh/main/guide/installation/), [zoxide](https://github.com/ajeetdsouza/zoxide#installation), [eza](https://github.com/eza-community/eza/blob/main/INSTALL.md), [fnm](https://github.com/Schniz/fnm#installation), [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) y [Neovim](https://github.com/neovim/neovim/blob/master/INSTALL.md).

Elija `tmux`, `herdr` o `both`. `both` es el valor predeterminado y enlaza las dos configuraciones; no obliga a usar ambos. Para una sesión normal, tmux es la opción general. [Herdr](https://herdr.dev) es una alternativa parecida a tmux, enfocada en sesiones con agentes de IA. No anide un multiplexor dentro del otro.

### macOS

```bash
git clone https://github.com/LuHer18/Dotfiles-LuHer.git
cd Dotfiles-LuHer
./scripts/check.sh
./install.sh --dry-run --multiplexer tmux
# Revise la vista previa y, si es correcta:
./install.sh --multiplexer tmux
```

### Linux

```bash
git clone https://github.com/LuHer18/Dotfiles-LuHer.git
cd Dotfiles-LuHer
./scripts/check.sh
./install.sh --dry-run --multiplexer tmux
# Revise la vista previa y, si es correcta:
./install.sh --multiplexer tmux
```

Cambie `tmux` por `herdr` si solo quiere Herdr, o por `both` para el comportamiento predeterminado. `check.sh` y `--dry-run` no activan ni modifican la configuración del usuario. No ejecute la instalación hasta revisar la vista previa.

## Requisitos

El entorno mínimo para ejecutar las comprobaciones es `bash` y, para validar todo lo posible, también `python3` y `zsh`. El script omite las comprobaciones de herramientas que no estén instaladas y valida tmux solo si encuentra `tmux`. `shellcheck` es opcional. La configuración de zsh usa `nvim` como editor; instálelo si desea utilizar ese editor.

Aplicaciones recomendadas o necesarias según lo que vaya a usar:

- **Necesarios para sus funciones:** zsh; Ghostty para usar el terminal configurado; Starship para el prompt; y una Nerd Font (la configuración usa JetBrainsMono Nerd Font).
- **Multiplexor:** tmux **o** Herdr; no necesita instalar ambos. En macOS puede instalar tmux/Starship y otras herramientas con su gestor habitual. Instale Herdr desde su [sitio oficial](https://herdr.dev) o [repositorio oficial](https://github.com/herdrdev/herdr); no se prescriben paquetes para cada distribución.
- **macOS:** Aerospace es opcional y solo se enlaza en macOS. Instálelo desde su [documentación oficial](https://nikitabobko.github.io/AeroSpace/).
- **Linux:** el portapapeles de tmux necesita `wl-copy` en Wayland o `xclip`/`xsel` en X11. Sin ellos, tmux sigue funcionando, pero no copiará al portapapeles.

`install.sh` no instala aplicaciones. `./dotfiles setup` instala solo métodos oficiales predefinidos, con gestores ya existentes y arquitectura compatible; nunca instala Homebrew/pnpm/node automáticamente.

Las integraciones opcionales de zsh (`eza`, `fnm`, `zoxide`, `atuin`, `zsh-autosuggestions` y `zsh-syntax-highlighting`) solo se activan cuando están disponibles. Kitty es opcional para `kitten icat`.

## Qué enlaza el instalador

`install.sh` enlaza Ghostty, OpenCode, Starship y zsh; en macOS también Aerospace. Según el selector, enlaza tmux (`~/.tmux.conf` y `~/.config/tmux/scripts`) y/o Herdr. `dotfiles.json` documenta los mapeos, pero no es un instalador.

Solo cuando `install.sh` debe sustituir un destino de configuración existente, lo mueve a `~/.dotfiles-backups/<timestamp>/` antes de crear el enlace. Estos respaldos corresponden a reemplazos de configuración; no son aplicaciones instaladas ni se crean durante la instalación de herramientas.

### Restaurar un respaldo con seguridad

Compruebe primero que el destino es el enlace administrado y quite solo ese enlace; no use un `rm -r` recursivo:

```bash
if [ -L "$HOME/.zshrc" ]; then
  readlink "$HOME/.zshrc"
  rm "$HOME/.zshrc"
fi
mv "$HOME/.dotfiles-backups/<timestamp>/.zshrc" "$HOME/.zshrc"
```

Aplique el mismo procedimiento al destino correspondiente, verificando siempre el enlace y la ruta del respaldo antes de moverlo.

## Comportamiento y atajos

- **tmux:** el prefijo es `Ctrl-a`; `Ctrl-a c` crea una ventana, `Ctrl-a d` divide verticalmente, `Ctrl-a v` divide lado a lado, `Ctrl-a h/j/k/l` mueve el foco y `Ctrl-a H/J/K/L` redimensiona. `Alt`+flechas también mueve el foco. `Ctrl-a r` recarga `~/.tmux.conf`.
- **Herdr:** usa `Ctrl-a`; `Ctrl-a c`, `n` y `p` crean y recorren pestañas; `Ctrl-a h/j/k/l` mueve el foco; `Ctrl-a v` y `d` dividen; `Ctrl-a r` recarga y `Ctrl-a Shift-r` entra en modo de redimensionamiento. Requiere `/bin/zsh` o adaptar su configuración.
- **Ghostty:** `Command+Shift+O` abre la vista general de pestañas; copia al seleccionar texto.
- **macOS/Aerospace:** `Ctrl-Alt-1..6` cambia de espacio y `Ctrl-Alt-Shift-1..6` mueve la ventana; consulte `config/aerospace/aerospace.toml` para el resto de atajos y reglas.

## Instalar Pi

[Pi](https://pi.dev) es un agente de programación minimalista para la terminal: puede trabajar con archivos y comandos, y se amplía mediante paquetes, extensiones, skills y temas. Esta instalación es opcional e independiente de `install.sh`: instala Pi y configura sus paquetes, preferencias y tema, sin activar los demás dotfiles del repositorio.

Requiere macOS o Linux, Node.js `>=22.19.0`, `python3`, `pnpm` y `npm`. Además, pnpm debe tener configurado manualmente `global-bin-dir`; `pnpm setup` no se ejecuta automáticamente y el script no modifica `PATH`, shells ni usa `sudo`. La CLI queda fijada en `@earendil-works/pi-coding-agent@0.85.1`.

Desde la raíz de este repositorio, elija **una** ruta: instalación nueva (rechaza cualquier destino existente) o combinación con una configuración de Pi ya existente. El `dry-run` solo muestra el plan; no escribe ni invoca gestores.

### Instalación nueva

```bash
cd /ruta/a/Dotfiles-LuHer
./scripts/setup-pi.sh --dry-run
# Revise el plan; después, si lo aprueba:
./scripts/setup-pi.sh
```

### Configuración existente

```bash
cd /ruta/a/Dotfiles-LuHer
./scripts/setup-pi.sh --dry-run --merge
# Revise el plan; después, si lo aprueba:
./scripts/setup-pi.sh --merge
```

La combinación conserva ajustes y paquetes no relacionados, reemplaza deliberadamente las siete versiones fijadas y respalda `settings.json` y el tema coincidente con permisos privados. No lee ni copia `auth.json`, `mcp.json`, `models.json` ni `sessions/`. Tras instalar, reinicie Pi y autentíquese manualmente con `/login`; las conexiones MCP y Engram, así como sus secretos, deben configurarse aparte y no se restauran.

| Paquete | Versión | Propósito |
| --- | ---: | --- |
| `gentle-pi` | `2.5.0` | Capa de operación para flujos SDD/OpenSpec, coordinación de agentes, TDD estricto, guardas y revisión; incluye preferencias y UI de Gentle Shell. |
| `pi-intercom` | `0.13.0` | Mensajería 1:1 entre sesiones Pi locales mediante un broker IPC. |
| `pi-web-access` | `0.28.0` | Búsqueda web, extracción de contenido y herramientas de acceso a páginas. |
| `pi-lens` | `4.1.5` | Diagnósticos y navegación mediante LSP, linters y análisis estructural. |
| `@juicesharp/rpiv-ask-user-question` | `2.9.0` | Cuestionarios estructurados con opciones tipadas para pedir decisiones al usuario sin adivinar. |
| `pi-mcp-adapter` | `2.32.1` | Puente hacia servidores MCP con descubrimiento bajo demanda y una herramienta proxy compacta. |
| `gentle-engram` | `0.1.12` | Integra memoria persistente y herramientas `mem_*`; requiere un servidor Engram configurado aparte, no incluido ni ejecutado por este repositorio. |

El snapshot también selecciona el tema `catppuccin-mocha` y activa los comandos de skills. Los paquetes y extensiones de terceros ejecutan código con los privilegios completos de su usuario; revise sus fuentes y mantenga privados los respaldos. Para fallos y recuperación, consulte la [guía detallada de Pi](config/pi/README.md).

## Comprobaciones

Para repetir validaciones sin instalar ni recargar nada:

```bash
./scripts/check.sh
```

Las pruebas de portabilidad simulan Linux y no representan una instalación ni una prueba en una máquina Linux real. `shellcheck` se ejecuta solo si está instalado.

Tras instalar, abra un shell nuevo o recargue zsh con `exec zsh`. Verifique los enlaces y ejecute `./scripts/check.sh` después de actualizar el repositorio.

## Recarga de tmux y Herdr

Para aplicar cambios de tmux o Herdr, use sus atajos de recarga o cierre y vuelva a abrir la sesión.
