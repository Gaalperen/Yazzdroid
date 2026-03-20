#!/usr/bin/env bash

set -e

APP_NAME="yazzdroid"
INSTALL_DIR="/usr/local/bin/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/$APP_NAME"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_PATH="$SERVICE_DIR/yazz-loop.service"

echo "=== Instalando $APP_NAME ==="

# ============================================================
# Detectar gestor de paquetes
# ============================================================
detect_pkg() {
    if command -v pacman &>/dev/null; then PKG="pacman"
    elif command -v apt &>/dev/null; then PKG="apt"
    elif command -v dnf &>/dev/null; then PKG="dnf"
    else PKG="unknown"
    fi
}

# ============================================================
# scrcpy ◕‿↼
# ============================================================
install_scrcpy() {
    if command -v scrcpy &>/dev/null; then
        echo "[OK] scrcpy ya estaba instalada"
        return
    fi

    echo "[INFO] Instalando scrcpy..."

    case "$PKG" in
        pacman) sudo pacman -Sy --needed scrcpy ;;
        apt) sudo apt update && sudo apt install -y scrcpy ;;
        dnf) sudo dnf install -y scrcpy ;;
        *) echo "Instala scrcpy manualmente"; exit 1 ;;
    esac
}

# ============================================================
# estructura de carpetas
# ============================================================
setup_dirs() {
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$SERVICE_DIR"
}

# ============================================================
# Instalar script principal
# ============================================================
install_script() {
cat > "$INSTALL_DIR/$APP_NAME" <<'EOF'
#!/usr/bin/env bash
#
##############################################
# YAZZDROID, UN MENU CLI PARA SCRCPY INTERACTIVO (flechas + WASD)
##############################################
#

# ---------------------------
# Colores (ANSI truecolor)
# ---------------------------
BLUE="\e[38;2;124;194;255m"      # títulos
PINK="\e[38;2;255;199;199m"     # color base
RED="\e[38;2;224;74;74m"        # errores/alertas
SELECTOR_COLOR="\e[38;2;255;211;116m"  # selector (amarillo) rgb(255,211,116)
BOLD="\e[1m"
RESET="\e[0m"
DIM="\e[2m"

# Selector en negrita y color
SELECTOR="${SELECTOR_COLOR}${BOLD}➤UwU➤${RESET}"
# Estoy usando: ➤UwU➤ como selector. Puede cambiarse por cualquier wea.

# ---------------------------
# Variables internas
# ---------------------------
selected_device=""
selected_device_name=""
menu_index=0

########################################################################################################
# Actualizar título de la terminal
set_title() {
    # dinámico: YAZZDROID <device> --
    if [[ -n "$selected_device_name" ]]; then
        title="-==YAZZDROID - ${selected_device_name} ==-"
    else
        title="--yazzdroid--"
    fi
    # establece título de la ventana del emulador de terminal
    echo -ne "\033]0;${title}\007"
}

########################################################################################################
# ---------------------------
# Función: detectar dispositivos
# ---------------------------
detect_devices() {
    # lista ids (filtra offline/unauthorized)
    mapfile -t DEVICES < <(adb devices -l 2>/dev/null | awk 'NR>1 && $2=="device"{print $1}')
    DEVICE_NAMES=()
    for id in "${DEVICES[@]}"; do
        # intenta obtener modelo legible; si no, usa manufacturer+model o fallback al id
        model=$(adb -s "$id" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
        brand=$(adb -s "$id" shell getprop ro.product.brand 2>/dev/null | tr -d '\r')
        if [[ -n "$model" && "$model" != "null" ]]; then
            name="$model"
        elif [[ -n "$brand" && "$brand" != "null" ]]; then
            name="$brand"
        else
            name="$id"
        fi
        # limpiar secuencias de control por si acaso
        name=$(echo -n "$name" | tr -d '\000-\037')
        DEVICE_NAMES+=("$name")
    done
}

########################################################################################################
# ---------------------------
# Función: leer teclas (flechas + wasd + space + q)
# ---------------------------
read_key() {
    IFS= read -rsn1 key 2>/dev/null || return 1

    # Flechas: ESC [
    if [[ $key == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.001 rest 2>/dev/null || rest=""
        case "$rest" in
            "[A") echo "UP"; return;;
            "[B") echo "DOWN"; return;;
            "[C") echo "ENTER"; return;;
            "[D") echo "QUIT"; return;;
            *) return;;
        esac
    fi

    case "$key" in
        w|W) echo "UP";;
        s|S) echo "DOWN";;

        "") echo "ENTER";;      # Enter
        " ") echo "ENTER";;     # Space

        q|Q) echo "QUIT";;      # quitear/back
        *) ;; # ignorar otras teclas
    esac
}



########################################################################################################
# ---------------------------
# Dibujar menú general
# ---------------------------
draw_menu() {
    set_title
    clear
    echo -e "${BLUE}=== YAZZDROID MENU ===${RESET}"
    echo

    if [[ -n "$selected_device" ]]; then
        # mostrar nombre y id; reset para evitar que colores "se peguen"
        echo -e "Dispositivo seleccionado: ${PINK}${selected_device_name}${RESET} ${DIM}[${selected_device}]${RESET}"
    else
        echo -e "${RED}Ningún dispositivo seleccionado${RESET}"
    fi

    echo

    local options=("Seleccionar dispositivo"
                   "Micrófono 🎙️"
                   "Audio 🔊"
                   "Pantalla"
                   "Cámara"
                   "← Salir")

    for i in "${!options[@]}"; do
        if [[ $i -eq $menu_index ]]; then
            # selector con color/negra (sin '>' extra)
            echo -e "${SELECTOR} ${PINK}${options[$i]}${RESET}"
        else
            echo "    ${options[$i]}"
        fi
    done

    echo
    echo -e "${DIM}Usa ↑/↓ o W/S para navegar. Enter/Space/→ confirmar. Q para volver/salir.${RESET}"
}

########################################################################################################
# ---------------------------
# Menú: seleccionar dispositivo
# ---------------------------
menu_devices() {
    detect_devices
    if [[ ${#DEVICES[@]} -eq 0 ]]; then
        clear
        echo -e "${RED}No se detectan dispositivos ADB.${RESET}"
        echo "Conecta un dispositivo Android con 'depuración USB' y habilita ADB."
        read -rp "Presiona Enter para volver…"
        return
    fi

    local dev_idx=0
    while true; do
        clear
        echo -e "${BLUE}=== Seleccionar dispositivo ===${RESET}"
        echo -e "${DIM}(Presiona Q para volver)${RESET}"
        echo

        for i in "${!DEVICES[@]}"; do
            if [[ $i -eq $dev_idx ]]; then
                echo -e "${SELECTOR} ${PINK}${DEVICE_NAMES[$i]}${DIM} [${DEVICES[$i]}]${RESET}"
            else
                echo -e "    ${DEVICE_NAMES[$i]}${DIM} [${DEVICES[$i]}]${RESET}"
            fi
        done

        key=$(read_key)

        case "$key" in
            UP) ((dev_idx--));;
            DOWN) ((dev_idx++));;
            ENTER)
                selected_device="${DEVICES[$dev_idx]}"
                selected_device_name="${DEVICE_NAMES[$dev_idx]}"
                set_title
                return
                ;;
            QUIT) return ;;
        esac

        # límites (wrap-around)
        ((dev_idx < 0)) && dev_idx=$((${#DEVICES[@]} - 1))
        ((dev_idx >= ${#DEVICES[@]})) && dev_idx=0
    done
}

########################################################################################################
# ---------------------------
# Ejecutar micrófono (sin vídeo)
# ---------------------------
run_mic() {
    if [[ -z "$selected_device" ]]; then
        clear
        echo -e "${RED}Primero selecciona un dispositivo.${RESET}"
        read -rp "Enter para volver…"
        return
    fi

    local options=("Micrófono RAW"
                   "Normalizado"
                   "Micrófono Procesado"
                   "← Volver")
    local idx=0

    while true; do
        clear
        echo -e "${BLUE}=== Micrófono ===${RESET}"
        echo -e "${DIM}(Presiona Q para volver)${RESET}"
        echo

        for i in "${!options[@]}"; do
            if [[ $i -eq $idx ]]; then
                echo -e "${SELECTOR} ${PINK}${options[$i]}${RESET}"
            else
                echo "    ${options[$i]}"
            fi
        done

        key=$(read_key)
        case "$key" in
            UP) ((idx--));;
            DOWN) ((idx++));;
            ENTER)
                case $idx in
                    0) scrcpy -s "$selected_device" --no-window --no-video --audio-source=mic-unprocessed;;
                    1) scrcpy -s "$selected_device" --no-window --no-video --audio-source=mic;;
                    2) scrcpy -s "$selected_device" --no-window --no-video --audio-source=mic-voice-communication;;
                    3)return;;
                esac
                ;;
            QUIT) return;;
        esac

        ((idx < 0)) && idx=$((${#options[@]} - 1))
        ((idx >= ${#options[@]})) && idx=0
    done
}

########################################################################################################
# ---------------------------
# Ejecutar output de audio (sin vídeo)
# ---------------------------
run_audio() {
    if [[ -z "$selected_device" ]]; then
        clear
        echo -e "${RED}Primero selecciona un dispositivo.${RESET}"
        read -rp "Enter para volver…"
        return
    fi

    local options=("Output normal"
                   "Output duplicada (sigue sonando en android)"
                   "← Volver")
    local idx=0

    while true; do
        clear
        echo -e "${BLUE}=== Audio ===${RESET}"
        echo -e "${DIM}(Presiona Q para volver)${RESET}"
        echo

        for i in "${!options[@]}"; do
            if [[ $i -eq $idx ]]; then
                echo -e "${SELECTOR} ${PINK}${options[$i]}${RESET}"
            else
                echo "    ${options[$i]}"
            fi
        done

        key=$(read_key)
        case "$key" in
            UP) ((idx--));;
            DOWN) ((idx++));;
            ENTER)
                case $idx in
                    0) scrcpy -s "$selected_device" --no-window --no-video --audio-source=output;;
                    1) scrcpy -s "$selected_device" --no-window --no-video --audio-source=playback --audio-dup;;
                    2) return;;
                esac
                ;;
            QUIT) return;;
        esac

        ((idx < 0)) && idx=$((${#options[@]} - 1))
        ((idx >= ${#options[@]})) && idx=0
    done
}


########################################################################################################
# ---------------------------
# Menú pantalla (audio / awake)
# ---------------------------
menu_screen() {
    if [[ -z "$selected_device" ]]; then
        clear
        echo -e "${RED}Primero selecciona un dispositivo.${RESET}"
        read -rp "Enter para volver…"
        return
    fi

    local options=("Pantalla"
                   "Pantalla + Audio 🔊"
                   "Pantalla + Micro 🎙️"
                   "← Volver")
    local idx=0

    while true; do
        clear
        echo -e "${BLUE}=== Pantalla ===${RESET}"
        echo -e "${DIM}(Presiona Q para volver)${RESET}"
        echo

        for i in "${!options[@]}"; do
            if [[ $i -eq $idx ]]; then
                echo -e "${SELECTOR} ${PINK}${options[$i]}${RESET}"
            else
                echo "    ${options[$i]}"
            fi
        done

        key=$(read_key)
        case "$key" in
            UP) ((idx--));;
            DOWN) ((idx++));;
            ENTER)
                case $idx in
                    0) scrcpy --window-title="UwU Pantalla UwU" -s "$selected_device" --video-bit-rate=16M --turn-screen-off --stay-awake;;
                    1) scrcpy --window-title="UwU Pantalla UwU" -s "$selected_device" --video-bit-rate=16M --audio-source=output --stay-awake --turn-screen-off;;
                    2) scrcpy --window-title="UwU Pantalla UwU" -s "$selected_device" --video-bit-rate=16M --turn-screen-off --stay-awake --audio-source=mic;;
                    3) return;;
                esac
                ;;
            QUIT) return;;
        esac

        # wrap
        ((idx < 0)) && idx=4
        ((idx > 4)) && idx=0
    done
}

########################################################################################################
### CÁMARA
# ---------------------------
# Menú orientación (devuelve CAMERA_ORIENTATION)
# ---------------------------
menu_orientacion() {
    local opciones=("0° (normal)" "90°" "180°" "270°" "← Volver")
    local valores=("0" "90" "180" "270")
    local idx=0

    while true; do
        clear
        echo -e "${BLUE}=== Orientación de cámara ===${RESET}"
        echo -e "${DIM}(Presiona Q para volver)${RESET}"
        echo

        for i in "${!opciones[@]}"; do
            if [[ $i -eq $idx ]]; then
                echo -e "${SELECTOR} ${PINK}${opciones[$i]}${RESET}"
            else
                echo "    ${opciones[$i]}"
            fi
        done

        key=$(read_key)
        case "$key" in
            UP) ((idx--));;
            DOWN) ((idx++));;
            ENTER)
                if [[ $idx -eq 4 ]]; then
                    CAMERA_ORIENTATION=""
                    return
                fi
                CAMERA_ORIENTATION="${valores[$idx]}"
                return
                ;;
            QUIT) CAMERA_ORIENTATION=""; return;;
        esac

        ((idx < 0)) && idx=4
        ((idx > 4)) && idx=0
    done
}

# ---------------------------
# Menú cámara (flujo: cámara -> orientación -> micrófono)
# ---------------------------
menu_camera() {
    if [[ -z "$selected_device" ]]; then
        clear
        echo -e "${RED}Primero selecciona un dispositivo.${RESET}"
        read -rp "Enter para volver…"
        return
    fi

    local options=("Frontal (sin micrófono)"
                   "Frontal (con micrófono) 🎙️"
                   "Trasera (sin micrófono)"
                   "Trasera (con micrófono) 🎙️"
                   "← Volver")

    local cam_args=("" "" "" "")
    cam_args[0]="--camera-facing=front --no-audio"
    cam_args[1]="--camera-facing=front --audio-source=mic"
    cam_args[2]="--camera-facing=back --no-audio"
    cam_args[3]="--camera-facing=back --audio-source=mic"

    local idx=0

    while true; do
        clear
        echo -e "${BLUE}=== Cámara ===${RESET}"
        echo -e "${DIM}(Flujo: Cámara → Orientación → Micrófono. Presiona Q para volver)${RESET}"
        echo

        for i in "${!options[@]}"; do
            if [[ $i -eq $idx ]]; then
                echo -e "${SELECTOR} ${PINK}${options[$i]}${RESET}"
            else
                echo "    ${options[$i]}"
            fi
        done

        key=$(read_key)
        case "$key" in
            UP) ((idx--));;
            DOWN) ((idx++));;
            ENTER)
                if [[ $idx -eq 4 ]]; then
                    return
                fi

                # 1) seleccionada la cámara -> pedir orientación
                menu_orientacion
                # si user pulsó Q en orientación, CAMERA_ORIENTATION=""
                ORIENT_FLAG=""
                if [[ -n "$CAMERA_ORIENTATION" ]]; then
                    ORIENT_FLAG="--capture-orientation=${CAMERA_ORIENTATION}"
                fi

                # 2) Finalmente ejecuta con las weas elegidas (cam_args incluye mic cuando corresponde)
                scrcpy -s "$selected_device" --window-title="UwU cam UwU" --video-source=camera ${cam_args[$idx]} $ORIENT_FLAG
                ;;
            QUIT) return;;
        esac

        ((idx < 0)) && idx=4
        ((idx > 4)) && idx=0
    done
}

########################################################################################################
# ---------------------------
# Bucle principal
# ---------------------------
while true; do
    draw_menu
    key=$(read_key)

    case "$key" in
        UP) ((menu_index--));;
        DOWN) ((menu_index++));;
        ENTER)
            case $menu_index in
                0) menu_devices;;
                1) run_mic;;
                2) run_audio;;
                3) menu_screen;;
                4) menu_camera;;
                5) clear; exit 0;;
            esac
            ;;
        QUIT) clear; exit 0;;
    esac

    ((menu_index < 0)) && menu_index=5
    ((menu_index > 5)) && menu_index=0
done

########################################################################################################
# Fin del script
EOF

chmod +x "$INSTALL_DIR/$APP_NAME"

# crear enlace ejecutable
ln -sf "$INSTALL_DIR/$APP_NAME" "$BIN_PATH"
}

# ============================================================
# Instalar servicio audio yazz-loop
# ============================================================
install_service() {
cat > "$SERVICE_PATH" <<'EOF'
[Unit]
Description=Yazz-loop. Cables Virtuales en linux. (-‿◦☀)
Wants=pipewire.service
After=pipewire.service wireplumber.service

[Service]
Type=oneshot
RemainAfterExit=yes

# Estos comandos crean los módulos virtuales
#	1-a. Modulo OBS_out
ExecStart=/usr/bin/pactl load-module module-null-sink sink_name=OBS_out device.description="OBS_out"
#	1-b.Modulo OBS_in
ExecStart=/usr/bin/pactl load-module module-remap-source source_name=OBS_in master=OBS_out.monitor source_properties=device.description="OBS_mic"

#   2-a. Módulo Loop_out
ExecStart=/usr/bin/pactl load-module module-null-sink sink_name=Loop_out device.description="Loop_out"
#	2-b.Modulo Loop_in
ExecStart=/usr/bin/pactl load-module module-remap-source source_name=Loop_in master=Loop_out.monitor source_properties=device.description="Loop_mic"

# El comando de stop debe encontrar el ID de los módulos para poder descargarlos.
# 1. Busca el ID de OBS_out y lo descarga.
ExecStop=/usr/bin/pactl unload-module $(/usr/bin/pactl list modules | grep -B 2 "Argument: sink_name=OBS_out" | grep "Module \#" | awk '{print $2}')
# 2. Lo mismo con OBS_in.
ExecStop=/usr/bin/pactl unload-module $(/usr/bin/pactl list modules | grep -B 2 "Argument: source_name=OBS_in" | grep "Module \#" | awk '{print $2}')
# 3. Lo mismo con Loop_out
ExecStop=/usr/bin/pactl unload-module $(/usr/bin/pactl list modules | grep -B 2 "Argument: sink_name=Loop_out" | grep "Module \#" | awk '{print $2}')
# 4. Misma vaina
ExecStop=/usr/bin/pactl unload-module $(/usr/bin/pactl list modules | grep -B 2 "Argument: sink_name=Loop_out" | grep "Module \#" | awk '{print $2}')

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reexec
systemctl --user enable --now yazz-loop.service
}

# ============================================================
# README
# ============================================================
install_readme() {
cat > "$INSTALL_DIR/README.md" <<'EOF'
# Yazzdroid
> Una aplicación CLI para acceder al audio, la cámara, micrófono y pantalla de cualquier dispositivo con Android.

Una vez instalado, solo ejecuta yazzdroid desde la terminal de comandos. Navega a través del menú usando las teclas direccionales, ‘w’, ‘s’, ‘space’ y ‘enter’.

Para funcionar, Yazzdroid utiliza ‘SCRCPY’ (screen copy). No se necesita instalar nada en el teléfono, tampoco ser usuario root. Tan solo hace falta activar la ‘depuración USB’ en las opciones de desarrollador y conectar el dispositivo android al PC. Algunos dispositivos requieren intervención manual para permitir la conexión.

---
---
## Instalación
Para instalar Yazzdroid basta con usar el script “install.sh”. Con este fin necesitas darle permisos para ejecutarse.

Navega en la terminal hasta el directorio donde se encuentra el script.
> chmod +x install.sh

El instalador hace lo siguiente:
1. Verifica el tipo de gestor de paquetes, e instala scrcpy si no está instalado.
2. Crea un script llamado yazzdroid en: “$HOME/.local/share/”. Este es aquel que se invocará desde la terminal.
	- **Nota**: “~/.local/bin” tiene que estar en tu PATH para que funcione. Si no lo está agregalo usando:
		> export PATH="$HOME/.local/bin:$PATH"
3. Crea un servicio de usuario llamado “yazz-loop.service” en el directorio: "$HOME/.config/systemd/user".
4. Como buena práctica, también deja una copia de los archivos “README.md” y “Licence” en el directorio “$HOME/.local/share/”.

Puedes instalar Yazzdroid manualmente copiando el script en un directorio del path. Luego copiar el archivo del servicio en el directorio de systemd, activarlo e iniciarlo. Por defecto, el script de instalación utiliza el directorio de usuario para systemd; pero también es posible instalarlo en el directorio root.

> systemctl --user daemon-reexec
> systemctl --user enable --now yazz-loop.service
## Desinstalar

Desinstalarlo implica eliminar el script “yazzdroid”. Luego detener y eliminar el servicio “yazz-loop.service”.

Puedes desinstalar haciendo:

→ Quitar el script del path
> rm -f $HOME/.local/share/yazzdroid

→ Detener y desactivar el servicio
> systemctl --user stop yazz-loop.service
> systemctl --user disable yazz-loop.service

→ Eliminar el servicio
> rm -f ~/.config/systemd/user/yazz-loop.service

## Funciones

Una sesión de Yazzdroid permite:
- Escuchar el micrófono
- Escuchar la salida de audio
- Ver la pantalla y controlarla
- Ver la cámara

Puedes iniciar más de una sesión a la vez. También es posible manejar más de un dispositivo android a la vez. Para comenzar la sesión primero es necesario seleccionar un dispositivo. Yazzdroid lista las id, y en lo posible el código del modelo de todos los dispositivos android conectados al pc por usb.

### 1. Micrófono
Por defecto Yazzdroid NO crea una entrada de audio en el PC. Sino que genera un nuevo stream de audio; uno como el que cualquier otra aplicación crearía al funcionar. Automáticamente este stream sonará en el dispositivo de reproducción de audio en uso. Para utilizar el stream de audio del micrófono es necesario que el output del stream de scrcpy sea asignado a una de las salidas de audio virtual creadas por Yazzdroid (‘OBS_out’, o ‘Loop_out’).
Para mover el stream a cualquiera de estos dispositivos requieres intervención manual. Utiliza una herramienta como “Pavucontrol”, “Qpwgraph”, o “Plasma/Volume de KDE”.

Yazzdroid crea dos dispositivos virtuales de audio. Cada uno tiene tiene un output que escucha y un input que emitirá sonido. Gracias a que son dos, puede asignarse el stream directo a ‘Loop_out’, luego escucharlo y añadirle filtros en OBS Studio desde Loop_in; y finalmente asignar como dispositivo de monitorización a “OBS_out” para poder usar “OBS_in” como entrada de audio en cualquier aplicación.

Hay tres opciones para obtener el audio del micrófono. Ninguna de estas abre una ventana nueva. En versiones inferiores o iguales a Android 10 scrcpy no es capaz de obtener el audio.
Para salir solo hace falta cerrar la terminal, o utilizar el atajo de teclado: ‘Cntrol + C’.

1. Microfono RAW
	- No tiene procesamiento de audio, equalización ni normalización. Está completamente en raw. Dependiendo del dispositivo, podría servir para grabar audio binaural (ASMR).
2. Micrófono con audio normalizado
	- Los valores de audio son normalizados por el dispositivo para elevar su volumen. Útil para uso general.
3. Micrófono Procesado
	- Funciona en algunos dispositivos. Aisla el sonido de la voz frente al ruido de fondo. Es importante considerar que transforma el audio a *mono*.

### 2. Audio
De igual forma que con el micrófono, se crea un stream de audio nuevo asociado al dispositivo de reproducción en uso. Hay dos métodos:

1. Output normal
	- Se crea un stream de audio nuevo que recibe todo el audio que suena en el dispositivo android. Mientras tengas el proceso abierto el sonido solo podrá ser escuchado en el PC.
2. Output duplicada
	- Sucede lo mismo que con la opción anterior, pero aún puede escucharse el sonido desde el dispositivo con android.
	- Solo funciona para dispositivos con Android 13, o superior. Es posible que algunas aplicaciones no permitan duplicar el sonido y solo se escuche en android (por ejemplo Brave Browser).

### 3. Pantalla
Se abre una nueva ventana en la cual se puede ver y controlar la pantalla del dispositivo. El dispositivo recibe el input del teclado y el ratón. No soporta apropiadamente el input de tabletas gráficas (no presión, rotación, ni tilt).
Al iniciar la sesión se apaga la pantalla del dispositivo para ahorrar batería, pero puede encenderse manualmente. Yazzdroid usa la opción de “–stay-awake” para que la sesión de usuario en el dispositivo android no se bloquee por inactividad. ‘Bloquear’ la pantalla requiere intervención manual presionando el botón para bloquearla. Asimismo, Yazzdroid usa una tasa de bits de 16 Mbps.
La ventana tiene rotación automática mientras que el dispositivo android tenga esta opción activada.

> Nota: La ventana se mostrará en negro cuando se trata de pestañas de navegación privada en el navegador, o la interfaz para desbloquear el dispositivo introduciendo la contraseña.

Se puede capturar la ventana con normalidad en OBS Studio, o en la función de compartir pantalla de aplicaciones varias.

Hay 3 opciones para recibir la pantalla:

1. Pantalla
2. Pantalla + Audio
	- Por defecto solo utiliza el output normal.
3. Pantalla + Micro
	- Por defecto escucha el micrófono con audio normalizado.


### 4. Cámara
De igual manera que la opción anterior abre una nueva ventana, solo que una que muestra la cámara del dispositivo. Por defecto, si hay más de una cámara frontal o trasera, Yazzdroid las trata como una sola frontal o trasera. No es posible controlar el flash.

Hay 4 opciones para capturar la cámara. Pero en todas se puede seleccionar el ángulo de rotación de la cámara, en 0°, 90°, 180°, y 270°. Por defecto en las opciones con micrófono también se usa el audio normalizado.

1. Frontal (sin micrófono)
2. Frontal (con micrófono)
3. Trasera (sin micrófono)
4. Trasera (con micrófono)


-----
-----

Yazzdroid se distribuye de manera gratuita bajo la licencia Apache 2.0.
Copyright (C) 2026 Yazilei

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

---
---

Si te gusta el proyecto puedes apoyarme en mi Kofi
https://ko-fi.com/yazilei

Encuentra mi arte en:
https://linktr.ee/yazilei
EOF
}

# ============================================================
# LICENSE Apache 2.0
# ============================================================
install_license() {
cat > "$INSTALL_DIR/LICENSE" <<'EOF'

                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
EOF
}

# ============================================================
# Verificar PATH
# ============================================================
check_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "[WARNING] ~/.local/bin no está en tu PATH"
        echo "Añade esto a tu shell config:"
        echo 'export PATH="$HOME/.local/bin:$PATH"'
    fi
}

# ============================================================
# MAIN
# ============================================================
main() {
    detect_pkg
    install_scrcpy
    setup_dirs
    install_script
    install_service
    install_readme
    install_license
    check_path

    echo
    echo "=== Instalación completada ==="
    echo "Ejecuta: $APP_NAME"
}

main
