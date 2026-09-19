# Haru

App de barra de menú para macOS que abre y cierra tus proyectos locales con
un atajo: abre VS Code en la carpeta, levanta sus contenedores de Docker y,
cuando dejás de usarlo, los apaga solos.

## El problema

Si tenés muchos proyectos en la Mac, abrir uno es siempre lo mismo: abrir
VS Code, buscar la carpeta, abrir una terminal y correr `docker compose up -d`
(y antes arrancar Docker Desktop si estaba cerrado). Al terminar, casi nunca
se corre el `docker compose down`: los contenedores quedan prendidos días
enteros, calientan la Mac y se comen memoria aunque la ventana de ese
proyecto se haya cerrado hace rato.

## Qué hace

- **⌥⌘P** abre un panel tipo Spotlight con tus proyectos: buscador, **↑↓**
  para moverte, **Enter** para abrir, **Esc** para cerrar el panel.
- La lista se arma sola: Haru busca proyectos en tus carpetas (ver
  [Configuración](#configuración)). Arriba los **abiertos**, después los
  **favoritos** (estrella) y el resto ordenado por cuántas veces los abriste.
- Abrir un proyecto abre VS Code en su carpeta y, si tiene archivo compose,
  hace `docker compose up -d`, arrancando Docker Desktop si hace falta.
- Cuando cerrás la ventana de VS Code de un proyecto abierto desde Haru, a los
  2 minutos hace `docker compose down`.
- Si no queda ningún contenedor corriendo, cierra Docker Desktop.
- **Apagar todo lo que no uso**: apaga Docker de todos los proyectos que
  tienen contenedores prendidos y ninguna ventana de VS Code.
- El ícono de la barra muestra cuántos proyectos tienen Docker prendido.

Haru trabaja solo con proyectos locales: no maneja SSH, contenedores remotos
ni entornos en la nube.

## Cómo funciona

**Abrir.** VS Code se abre con `open -a "Visual Studio Code" <carpeta>` (si ya
tenía ventana, la trae al frente). En paralelo, si el proyecto tiene
`docker-compose.yml`, `docker-compose.yaml`, `compose.yml` o `compose.yaml`:
si Docker Desktop no responde lo arranca con `docker desktop start` y después
corre `docker compose up -d` en la carpeta. Si algo falla, la fila queda en
rojo con el error; no se reintenta sola.

**Cierre automático con 2 minutos de gracia.** Cada 30 segundos Haru corre
`code --status`, que lista las ventanas abiertas de VS Code sin pedir ningún
permiso. Si la ventana de un proyecto abierto desde Haru ya no está, empieza
una cuenta de 2 minutos (se ve en la fila: "Se apaga en 1:30"). Si la volvés a
abrir antes, la cuenta se cancela. Si no, `docker compose down` y un aviso.
El estado se guarda en disco, así que reiniciar Haru no pierde la cuenta.
Solo se apagan solos los proyectos abiertos desde Haru; lo que levantaste a
mano no se toca.

**Cerrar.** El botón **Cerrar** de la fila hace `docker compose down` en el
momento y, si le diste permiso de Accesibilidad, también cierra la ventana de
VS Code.

**Docker Desktop.** Después de cualquier `docker compose down`, si
`docker ps` no muestra ningún contenedor (de ningún proyecto, sea de Haru o
no), Haru cierra Docker Desktop con `docker desktop stop`.

**Apagar todo lo que no uso.** Busca los proyectos con contenedores corriendo
y sin ventana de VS Code, te muestra la lista en el pie del panel y, si
confirmás, los apaga. Justo antes de apagar vuelve a mirar las ventanas: si
alguno se abrió mientras tanto, lo deja.

### Ante la duda, no apaga

Toda la lógica parte de ahí:

- Si `code --status` falla o no se puede interpretar, en ese ciclo no empieza
  ni termina ninguna cuenta.
- Si `docker ps` falla, no se apaga nada ni se cierra Docker Desktop.
- Si hay cualquier contenedor corriendo, sea de quien sea, Docker Desktop
  queda prendido.
- Si dos proyectos tienen carpetas con el mismo nombre, se consideran abiertos
  mientras haya una ventana con ese nombre.
- Un proyecto con una acción en curso (abriéndose, cerrándose) no se toca.

## Requisitos

- macOS 14 (Sonoma) o posterior.
- Command Line Tools de Xcode: `xcode-select --install`. No hace falta Xcode.
- [VS Code](https://code.visualstudio.com/) con el comando `code` instalado
  (en VS Code: paleta de comandos → *Shell Command: Install 'code' command in
  PATH*). Haru también lo busca dentro de `Visual Studio Code.app` en
  `/Applications` y `~/Applications`.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) 4.37 o
  posterior, para `docker desktop start` y `docker desktop stop`. Los
  proyectos sin archivo compose funcionan igual sin Docker.

## Instalación desde el código

```sh
git clone https://github.com/graficaves/haru.git
cd haru
./compilar.sh      # arma build/Haru.app para la arquitectura de tu Mac
./lanzar.sh        # la copia a ~/Applications y la abre
```

`./compilar.sh --universal` arma un binario para Apple Silicon e Intel.

Haru se registra para arrancar al iniciar sesión. Si macOS no lo permite, se
puede agregar a mano en Ajustes del Sistema → General → Ítems de inicio.

Para desinstalar: salí de Haru desde su menú, borrá `~/Applications/Haru.app`
y, si querés, `~/Library/Application Support/Haru`.

## Configuración

La primera vez Haru busca proyectos en las carpetas de esta lista que existan:
`~/Projects`, `~/Developer`, `~/Sites`, `~/code`, `~/dev`,
`~/Documents/GitHub`, y además en tu carpeta de usuario (`~`).

En cada una mira sus subcarpetas. Una subcarpeta es un proyecto si contiene
alguno de estos: `.git`, `package.json`, `composer.json`, `Package.swift`,
`pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`, `Gemfile`,
`index.html` o un archivo compose. Si no es proyecto, se mira un nivel más
adentro (para carpetas que agrupan proyectos, como `~/Projects/clientes/tienda`).
Dentro de un proyecto no se sigue bajando. Se ignoran las carpetas ocultas,
`node_modules`, `vendor`, `build`, `dist`, `backup`, `backups`, `Library` y
las que terminan en `-worktree`.

Desde el menú de la barra:

- **Carpetas de proyectos…** elige una o más carpetas y reemplaza las actuales.
- **Volver a buscar proyectos** repite la búsqueda (también se repite sola
  cada vez que abrís el panel).
- **Mostrar proyectos ocultos (N)** devuelve a la lista los que ocultaste.

En cada fila, clic derecho: **Ocultar de la lista** o **Mostrar en Finder**.

Todo se guarda en `~/Library/Application Support/Haru/preferencias.json`
(carpetas, favoritos, usos y ocultos), un JSON que se puede editar a mano
con Haru cerrada.

## Permisos

- **Ninguno para lo principal.** Abrir, levantar y apagar Docker, y detectar
  ventanas con `code --status` funcionan sin permisos especiales.
- **Accesibilidad (opcional):** solo para que el botón **Cerrar** cierre
  también la ventana de VS Code. Sin ese permiso, Cerrar apaga Docker y la
  ventana queda abierta. Se pide desde el menú de Haru → *Dar permiso para
  cerrar ventanas de VS Code…*. Como la app se firma ad-hoc al compilar,
  macOS la ve como una app nueva en cada compilación y **el permiso se pierde
  al recompilar**: hay que quitar Haru de la lista de Accesibilidad y volver a
  darlo.
- **Carpetas protegidas:** si alguna carpeta de búsqueda está dentro de
  Documentos, Escritorio o Descargas, macOS puede preguntar la primera vez si
  Haru puede acceder. Por la misma firma ad-hoc, puede volver a preguntar
  después de recompilar.

## Limitaciones

- **La detección de ventanas es por nombre de carpeta.** `code --status` solo
  informa el nombre de la carpeta de cada ventana, no la ruta. Si dos
  proyectos tienen carpetas con el mismo nombre (`~/a/site` y `~/b/site`),
  mientras una tenga ventana los dos cuentan como abiertos, y ninguno se
  apaga solo. Nunca se apaga de más, pero puede quedar prendido de más.
- **Títulos de ventana personalizados.** Si cambiaste `window.title` en VS
  Code de forma que el nombre de la carpeta no aparezca, Haru no ve la ventana
  y apagaría Docker a los 2 minutos de abrirlo.
- **Workspaces multi-carpeta** (`.code-workspace`): se ve el nombre del
  workspace, no el de cada carpeta.
- **Solo VS Code.** No detecta Cursor, VSCodium ni otros editores.
- **Solo proyectos locales**, con un archivo compose en la raíz de la carpeta.
- **Interfaz en español**, sin traducciones por ahora.

## Pruebas

```sh
./probar.sh
```

Compila y corre las pruebas de la lógica pura (escáner, preferencias, orden
de la lista, parser de `code --status` y vigilante). Las Command Line Tools no
traen XCTest usable sin Xcode, así que las pruebas son un ejecutable chico que
cuenta fallas. GitHub Actions corre `./probar.sh` y `./compilar.sh` en cada
push y pull request.

## Estructura del código

```
Sources/Logica/          lógica pura, sin interfaz ni procesos (probada)
  Modelos.swift            Proyecto: ruta, nombre, Docker, favorito, usos
  Escaner.swift            busca proyectos en las carpetas raíz
  Preferencias.swift       carpetas, favoritos, usos y ocultos; JSON
  Orden.swift              secciones de la lista y búsqueda
  ParserCodeStatus.swift   lee la salida de `code --status`
  Vigilante.swift          cuentas regresivas y qué apagar
Sources/App/             la app
  HaruApp.swift            punto de entrada, menú de la barra
  HaruStore.swift          estado y acciones (abrir, cerrar, apagar)
  Catalogo.swift           escaneo en segundo plano y preferencias en disco
  PanelHaru.swift          el panel: buscador, secciones y pie
  FilaProyecto.swift       una fila de la lista
  VentanaHaru.swift        la ventana flotante
  SelectorCarpetas.swift   diálogo para elegir las carpetas
  Docker.swift             docker compose y Docker Desktop
  VSCode.swift             abrir, leer y cerrar ventanas de VS Code
  Ejecutor.swift           corre comandos con tiempo límite
  AtajoGlobal.swift        atajo ⌥⌘P (Carbon, sin permisos)
  Aviso.swift              aviso propio en pantalla
  Persistencia.swift       estado del vigilante en disco
Tests/                   pruebas de Sources/Logica
compilar.sh  lanzar.sh  probar.sh
```

Se compila con `swiftc` directo, en modo Swift 5, sin proyecto de Xcode ni
Swift Package Manager.

## Licencia

MIT. Ver [LICENSE](LICENSE).

---

## In English

Haru is a macOS menu bar app for developers with many local projects. Press
**⌥⌘P** to get a Spotlight-like list of the projects it finds in your folders
(`~/Projects`, `~/Developer`, `~/Sites`, `~/code`, `~/dev`,
`~/Documents/GitHub` and your home folder, configurable from the menu).
Opening a project launches VS Code on it and runs `docker compose up -d`,
starting Docker Desktop if needed. When you close that project's VS Code
window, Haru waits 2 minutes and runs `docker compose down`; if no containers
are left, it quits Docker Desktop. A "shut down everything I'm not using"
button stops every project with running containers and no VS Code window.

The guiding rule is *when in doubt, don't shut down*: if VS Code or Docker
can't be read, nothing is stopped. Windows are detected with `code --status`
(no permissions needed), which only reports folder names, so projects with the
same folder name are treated as open together. Local projects only; no SSH or
remote environments. The UI is in Spanish.

Requirements: macOS 14+, Command Line Tools (`xcode-select --install`), VS Code
with the `code` command, Docker Desktop 4.37+. Build with `./compilar.sh`,
install with `./lanzar.sh`, run tests with `./probar.sh`. MIT licensed.
