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
PINK="\e[38;2;255;199;199m"     # selección color base
RED="\e[38;2;224;74;74m"        # errores/alertas
SELECTOR_COLOR="\e[38;2;255;211;116m"  # selector (amarillo) rgb(255,211,116)
BOLD="\e[1m"
RESET="\e[0m"
DIM="\e[2m"

# Selector en negrita y color
SELECTOR="${SELECTOR_COLOR}${BOLD}➤UwU➤${RESET}"
# Estoy usando: ➤ como selector. Puede cambiarse por cualquier wea.

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
    local opciones=("0° (normal)" "90°" "180°" "270°" "Volver")
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
