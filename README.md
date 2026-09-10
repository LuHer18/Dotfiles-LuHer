# Dotfiles LuHer

Configuración para macOS y Linux con zsh, Ghostty, Starship, OpenCode y un multiplexor de terminal. El instalador crea enlaces simbólicos y respalda los destinos existentes; no instala aplicaciones ni paquetes.

## Instalación rápida

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

Ghostty y Herdr no se instalan mediante este repositorio. Use sus instrucciones oficiales para su sistema; no se asumen paquetes concretos ni portabilidad completa de todas las herramientas entre distribuciones.

Las integraciones opcionales de zsh (`eza`, `fnm`, `zoxide`, `atuin`, `zsh-autosuggestions` y `zsh-syntax-highlighting`) solo se activan cuando están disponibles. Kitty es opcional para `kitten icat`.

## Qué enlaza el instalador

`install.sh` enlaza Ghostty, OpenCode, Starship y zsh; en macOS también Aerospace. Según el selector, enlaza tmux (`~/.tmux.conf` y `~/.config/tmux/scripts`) y/o Herdr. `dotfiles.json` documenta los mapeos, pero no es un instalador.

Los destinos existentes se mueven a `~/.dotfiles-backups/<timestamp>/` antes de crear el enlace. Estas copias son respaldos, no aplicaciones instaladas.

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

Las pruebas de portabilidad simulan Linux y no representan una prueba en su máquina Linux real. `shellcheck` se ejecuta solo si está instalado.

Tras instalar, abra un shell nuevo o recargue zsh con `exec zsh`. Verifique los enlaces y ejecute `./scripts/check.sh` después de actualizar el repositorio.

## Recarga de tmux y Herdr

Para aplicar cambios de tmux o Herdr, use sus atajos de recarga o cierre y vuelva a abrir la sesión.
