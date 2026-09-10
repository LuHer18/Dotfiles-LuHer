# Bootstrap de Pi

`scripts/setup-pi.sh` instala opcionalmente Pi en macOS o Linux y combina este snapshot sin activar autenticación, sesiones, MCP, modelos ni configuración de proyecto.

## Uso

Desde la raíz del repositorio, para una instalación nueva:

```bash
./scripts/setup-pi.sh --dry-run
# Revise el plan antes de instalar:
./scripts/setup-pi.sh
```

Si ya tiene configuración de Pi, use esta alternativa:

```bash
./scripts/setup-pi.sh --dry-run --merge
# Revise el plan antes de combinar configuraciones:
./scripts/setup-pi.sh --merge
```

Use `PI_CODING_AGENT_DIR=/ruta/absoluta` para otro destino. Exige Node >=22.19.0, Python 3, pnpm con `global-bin-dir` configurado y npm. Configure pnpm manualmente según su guía oficial; este script no modifica shell/PATH, no usa sudo ni instala gestores.

Instala exactamente `@earendil-works/pi-coding-agent@0.85.1` con `pnpm add --global --ignore-scripts` y los siete paquetes fijados mediante `pi install` fuera del proyecto. `--no-approve` está documentado por Pi para ignorar configuración de proyecto en ese comando; no es una sandbox.

## Seguridad y fallos

Los paquetes Pi ejecutan extensiones con todos los permisos del usuario y las skills pueden instruir acciones arbitrarias. Revise sus fuentes. El CLI usa `--ignore-scripts`, pero la instalación de extensiones ejecuta código de terceros. En `--merge` se lee y respalda privadamente el `settings.json` completo, que puede contener campos sensibles arbitrarios. Los archivos separados `auth.json`, `mcp.json`, `models.json` y `sessions/` nunca se leen ni copian.

El modo predeterminado rechaza cualquier destino existente. `--merge` respalda settings y el tema coincidente con permisos 600/700, conserva claves y paquetes no relacionados y reemplaza deliberadamente las siete versiones. Rechaza symlinks antes de cualquier gestor. Publica primero el tema y después settings: son dos operaciones atómicas separadas, no una transacción; un fallo posterior puede dejar solo el tema actualizado. Si falla un paquete, se detiene y deja estado parcial; no activa preferencias.

Los respaldos pueden contener los campos sensibles de `settings.json`; manténgalos fuera de Git y revíselos antes de restaurar. No incluyen credenciales almacenadas en archivos separados ni permiten deshacer las instalaciones de paquetes. Luego autentíquese manualmente con `pi` y `/login`. MCP, Engram y otros servicios requieren configuración manual; este bootstrap no instala servidores.

`--dry-run` no escribe ni invoca gestores.
