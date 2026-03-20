# Yazzdroid
---

> Una aplicación CLI para acceder al audio, la cámara, micrófono y pantalla de cualquier dispositivo con Android.

Una vez instalado, solo ejecuta yazzdroid desde la terminal de comandos. Navega a través del menú usando las teclas direccionales, ‘w’, ‘s’, ‘space’ y ‘enter’.

Para funcionar, Yazzdroid utiliza ‘SCRCPY’ (screen copy). No se necesita instalar nada en el teléfono, tampoco ser usuario root. Tan solo hace falta activar la ‘depuración USB’ en las opciones de desarrollador y conectar el dispositivo android al PC. 
→ Incluso con la depuración activada, algunos dispositivos requieren intervención manual para permitir la conexión en cada sesión.

---
---

## Instalación
Para instalar Yazzdroid basta con usar el script “install.sh”. Con este fin necesitas darle permisos para ejecutarse.

Navega en la terminal hasta el directorio donde se encuentra el script.
> chmod +x install.sh

El instalador hace lo siguiente:
1. Verifica el tipo de gestor de paquetes, e instala **scrcpy** si no está instalado.
	- **Nota**: Yazzdroid actualmente utiliza la versión 3.3.4 de scrcpy. Los repositorios de algunas distribuciones (como Ubuntu 25.10 o inferior) distribuyen versiones más antiguas (puede comprobarse usando el comando: ‘scrcpy -v’). En esos casos es necesario instalar manualmente la versión del repositorio de [Github](https://github.com/Genymobile/scrcpy/blob/master/doc/linux.md). Allí también se lista una tabla con las versiones del programa distribuídas en diferentes repositorios.
2. Crea un script llamado yazzdroid en: “/usr/local/bin”. Este es aquel que se invocará desde la terminal.
	- **Nota**: “/usr/local/bin” tiene que estar en tu PATH para que funcione. Si no lo está agregalo usando: 
		> export PATH="/usr/local/bin"

	En caso que no desees añadir esta ubicación al PATH, puedes mover el script a otro directorio del PATH. Si no sabes cuales directorios están registrados, utiliza  el comando:
	> echo $PATH

3. Crea un servicio de usuario llamado “yazz-loop.service” en el directorio: "$HOME/.config/systemd/user".
	- **Nota**: Yazzdroid crea un servicio usando systemd. 
4. Como buena práctica, también deja una copia de los archivos “README.md” y “Licence” en el directorio “$HOME/.local/bin”.

Puedes instalar Yazzdroid manualmente copiando el script en un directorio del path. Luego copiar el archivo del servicio en el directorio de systemd, activarlo e iniciarlo. Por defecto, el script de instalación utiliza el directorio de usuario para systemd; pero también es posible instalarlo en el directorio root.

> systemctl --user daemon-reexec
> systemctl --user enable --now yazz-loop.service

---
## Desinstalar

Desinstalarlo implica eliminar el script “yazzdroid”. Luego detener y eliminar el servicio “yazz-loop.service”.

Puedes desinstalar haciendo:

→ Quitar el script del path
> rm -f /usr/local/bin/yazzdroid

→ Detener y desactivar el servicio
> systemctl --user stop yazz-loop.service
> systemctl --user disable yazz-loop.service

→ Eliminar el servicio
> rm -f ~/.config/systemd/user/yazz-loop.service

→ Eliminar la carpeta con el README y Licence
> rm -f $HOME/.local/bin/yazzdroid

---
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


---
---

Yazzdroid es FOSS, y se distribuye de manera gratuita bajo la licencia Apache 2.0.
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

Si te gusta el proyecto puedes apoyarme en Kofi
https://ko-fi.com/yazilei

Encuentra mi arte en:
https://linktr.ee/yazilei
