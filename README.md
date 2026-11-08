# Ibiza Gussy — AC8227L firmware mod (boot + ARM2)

Modified boot and ARM2 images for **AutoChips AC8227L** car head units, plus boot-performance scripts. The package flashes two small partitions (BOOTIMG, 16 MiB, and ARM2, 4 MiB) with built-in SHA-256 verification and automatic rollback on failure.

**Designed for the AC8227L family of Android car head units.** Developed and tested on a **Jancar 8227L** (firmware `JCAC10003-OC2-V1.1.80R6-251118_0756`, kernel `3.18.79+`, Android reporting release 12 / API 27, 32-bit ARM, 2 GiB RAM, quad-core Cortex-A7). Other head units built on the AC8227L SoC with the same partition layout are expected to be compatible — the flash scripts **verify the partition names, sizes and current contents before writing anything**, so they will refuse to run on a mismatched unit.

---

## Features

1. **CPU overclock: 1300 → 1391 MHz (+7%)** — `images/boot-r3-1391.img` carries the stock kernel with a minimal patch: the cpufreq driver reads the `ibiza.oc=1391` boot parameter and selects the 1391 MHz entry (1300 mV, nominal voltage unchanged) together with the matching table limit. The stock 1300 MHz profile is the default; the overclock is armed in the boot header. The `performance` governor keeps all cores at the top frequency.
2. **Boot performance ("process killer")** — `scripts/boot-performance/` sets the `performance` CPU governor from `early-boot` (and again after `boot_completed` via the preinstall hook), so the CPU never throttles down during the slow boot phase; a companion service re-enables Wi-Fi after boot using the unit's saved networks.
3. **Rear camera (AHD) auto-connect at boot** — `images/arm2-camara-condicional-r3.bin` patches the ARM2 coprocessor firmware: in the early camera loop, after the decoder's initial scan, the normal handover to Android is kept when video is present; if Android has already announced ready (`APP_READY`) while reverse gear is still engaged and both the updated signal state and the fresh read report no signal, the original stop path is activated. An explicit `FORCE_STOP` keeps its stock semantics. No video-format changes, no TP9950 configuration during early boot.
4. **Wi-Fi restore after boot** — `scripts/boot-performance/ibiza-wifi-arranque.{rc,sh}` re-arms Wi-Fi (respecting airplane mode) shortly after boot and rechecks a few times in case a vendor service switches it off during startup.

## What is included

| Path | What | Size |
|---|---|---|
| `images/boot-r3-1391.img` | BOOTIMG to flash (overclock 1391 MHz) | 16 MiB |
| `images/arm2-camara-condicional-r3.bin` | ARM2 to flash (camera auto-connect) | 4 MiB |
| `images/originals/boot-original.img` | Stock BOOTIMG of the test unit (for restore) | 16 MiB |
| `images/originals/arm2-original.bin` | Stock ARM2 of the test unit (for restore) | 4 MiB |
| `images/originals/recovery-original.img` | Stock RECOVERY of the test unit (backup) | 16 MiB |
| `scripts/flashear-boot-r3-1391.sh` | Flashes BOOTIMG with verify + rollback | — |
| `scripts/flashear-arm2-r3.sh` | Flashes ARM2 with verify + rollback | — |
| `scripts/boot-performance/*` | Governor + Wi-Fi boot scripts and installers | — |
| `docs/` | Full technical log of the kernel/ARM2 modification process | — |
| `SHA256SUMS` | Hashes of all images | — |

## Prerequisites

- A head unit with the **AC8227L** SoC (e.g. Jancar 8227L family).
- ADB access to the unit (Wi-Fi on port 5555 is enabled by the stock firmware, or USB) with `su 0` (root) available — the stock firmware allows it.
- **Stable power** while flashing (do not let the unit power off mid-write).
- A full backup of your own stock partitions is strongly recommended (the scripts verify they match the test unit's stock hashes; if your unit ships a different stock build, update the `stock_hash` constants accordingly and use **your own** stock copies in `images/originals/`).

## Flashing (BOOTIMG + ARM2)

```sh
# 1) Push the images (note the exact filenames the scripts expect)
adb -s <unit-ip>:5555 push images/boot-r3-1391.img          /data/local/tmp/ibiza-boot-r3-1391.img
adb -s <unit-ip>:5555 push images/arm2-camara-condicional-r3.bin /data/local/tmp/ibiza-arm2-r3.bin
adb -s <unit-ip>:5555 push images/originals/boot-original.img /data/local/tmp/ibiza-boot-original.img
adb -s <unit-ip>:5555 push images/originals/arm2-original.bin  /data/local/tmp/ibiza-arm2-original.bin
adb -s <unit-ip>:5555 push scripts/flashear-boot-r3-1391.sh /data/local/tmp/flashear-boot-r3-1391.sh
adb -s <unit-ip>:5555 push scripts/flashear-arm2-r3.sh      /data/local/tmp/flashear-arm2-r3.sh

# 2) Flash BOOTIMG (verifies hardware, partition names/sizes, hashes; writes; verifies; rolls back on failure)
adb -s <unit-ip>:5555 shell su 0 sh /data/local/tmp/flashear-boot-r3-1391.sh

# 3) Flash ARM2 (same safety checks)
adb -s <unit-ip>:5555 shell su 0 sh /data/local/tmp/flashear-arm2-r3.sh

# 4) Reboot
adb -s <unit-ip>:5555 reboot
```

Both scripts use the eMMC software write-protect switch (`/sys/kernel/debug/mmc0/sw_wp_en`) and restore it after the operation. If the post-write verification fails, the stock image is written back and verified automatically.

## Boot performance (governor + Wi-Fi)

```sh
# Push the installers and payloads, then:
adb -s <unit-ip>:5555 shell su 0 sh /data/local/tmp/instalar-boot.sh            # governor from early-boot
adb -s <unit-ip>:5555 shell su 0 sh /data/local/tmp/instalar-wifi-arranque.sh   # Wi-Fi restore service
# Remove later with:
adb -s <unit-ip>:5555 shell su 0 sh /data/local/tmp/desinstalar-boot.sh
```

## Restoring stock

Push `images/originals/boot-original.img` and `arm2-original.bin` to `/data/local/tmp/` and `dd` them back:

```sh
su 0 sh -c 'echo 0 > /sys/kernel/debug/mmc0/sw_wp_en'
su 0 dd if=/data/local/tmp/ibiza-boot-original.img of=/dev/block/mmcblk0p10 bs=4096 count=4096
su 0 dd if=/data/local/tmp/ibiza-arm2-original.bin  of=/dev/block/mmcblk0p9  bs=4096 count=1024
su 0 sh -c 'sync; echo 1 > /sys/kernel/debug/mmc0/sw_wp_en'
```

Then verify with `sha256sum /dev/block/mmcblk0p10 /dev/block/mmcblk0p9` against `SHA256SUMS`.

## SHA-256

| File | SHA-256 |
|---|---|
| `images/boot-r3-1391.img` | `c5a00efe7ce94dfcdc2b1a0a73bb658ce287b5a6af5cf1704e15b5bda26f388a` |
| `images/arm2-camara-condicional-r3.bin` | `74933039931544fd57f86a21f2d3adb1e948b852e5db1f617751e85865e0752a` |
| `images/originals/boot-original.img` | `8911ad0e01bf9e229d76eeb5d43ee117e793553192458c69108c144dcd66dc57` |
| `images/originals/arm2-original.bin` | `679bb2274f50a9d2b99b840003284a9a7063674fd6fecc272d0652b25a6eba14` |
| `images/originals/recovery-original.img` | `c3d74deaf929eddc70f479a35577db5f3ff928f784e14d13e45d943d36eb5731` |

## Warnings

- Flashing boot partitions is done **at your own risk**. Keep power on during the operation.
- The images were built from, and verified against, the stock firmware of the test unit (Jancar 8227L, `JCAC10003-OC2-V1.1.80R6-251118_0756`). If your unit runs a different firmware revision, the pre-flight hash checks will stop the scripts — back up your own stock partitions first and adjust the `stock_hash` constants.
- Overclock to 1391 MHz is a +7% frequency step at the stock 1300 mV; the unit ran stable in testing, but long-term thermal behavior on other units is not guaranteed.
- Nothing in this package modifies `/system`, `/vendor`, `/data` or the recovery partition.

---

---

# Ibiza Gussy — Mod de firmware AC8227L (boot + ARM2)

Imágenes modificadas de boot y ARM2 para pantallas de coche **AutoChips AC8227L**, con scripts de rendimiento de arranque. El paquete flashea dos particiones pequeñas (BOOTIMG, 16 MiB, y ARM2, 4 MiB) con verificación SHA-256 integrada y rollback automático si falla.

**Diseñado para la familia de pantallas Android basadas en el SoC AC8227L.** Desarrollado y probado en una **Jancar 8227L** (firmware `JCAC10003-OC2-V1.1.80R6-251118_0756`, kernel `3.18.79+`, Android que declara release 12 / API 27, ARM de 32 bits, 2 GiB RAM, quad-core Cortex-A7). Otras pantallas con el SoC AC8227L y el mismo mapa de particiones deberían ser compatibles: los scripts de flash **verifican nombres de partición, tamaños y contenido actual antes de escribir**, y se niegan a continuar si no coinciden.

## Funciones

1. **Overclock de CPU: 1300 → 1391 MHz (+7 %)** — `images/boot-r3-1391.img` lleva el kernel de fábrica con un parche mínimo: el controlador cpufreq lee el parámetro de arranque `ibiza.oc=1391` y selecciona la entrada de 1391 MHz (1300 mV, voltaje nominal sin cambios) junto con el límite de tabla correspondiente. El perfil de 1300 MHz es el por defecto; el overclock se arma en el encabezado de boot. El gobernador `performance` mantiene todos los núcleos a máxima frecuencia.
2. **Rendimiento de arranque ("mata procesos")** — `scripts/boot-performance/` fija el gobernador `performance` desde `early-boot` (y de nuevo tras `boot_completed` vía el gancho preinstall), de modo que la CPU no reduce frecuencia durante la fase lenta de arranque; un servicio compañero reactiva el Wi-Fi tras el arranque usando las redes guardadas de la unidad.
3. **Cámara trasera (AHD) auto-conectada en el arranque** — `images/arm2-camara-condicional-r3.bin` parchea el firmware del coprocesador ARM2: en el bucle de cámara temprano, tras el escaneo inicial del decodificador, se conserva el traspaso normal a Android si hay vídeo; si Android ya anunció listo (`APP_READY`) y la marcha atrás sigue engranada y tanto el estado de señal actualizado como la lectura nueva indican ausencia, se activa la ruta original de parada. Una orden `FORCE_STOP` explícita conserva su semántica original. No cambia el formato de vídeo ni configura el TP9950 durante el arranque temprano.
4. **Restauración del Wi-Fi tras el arranque** — `scripts/boot-performance/ibiza-wifi-arranque.{rc,sh}` reactiva el Wi-Fi (respetando el modo avión) poco después del arranque y vuelve a comprobarlo varias veces por si un servicio del fabricante lo apaga durante el inicio.

## Contenido

| Ruta | Qué es | Tamaño |
|---|---|---|
| `images/boot-r3-1391.img` | BOOTIMG a flashear (overclock 1391 MHz) | 16 MiB |
| `images/arm2-camara-condicional-r3.bin` | ARM2 a flashear (cámara auto-conectada) | 4 MiB |
| `images/originals/boot-original.img` | BOOTIMG original de la unidad de prueba (restauración) | 16 MiB |
| `images/originals/arm2-original.bin` | ARM2 original de la unidad de prueba (restauración) | 4 MiB |
| `images/originals/recovery-original.img` | RECOVERY original de la unidad de prueba (respaldo) | 16 MiB |
| `scripts/flashear-boot-r3-1391.sh` | Flashea BOOTIMG con verificación + rollback | — |
| `scripts/flashear-arm2-r3.sh` | Flashea ARM2 con verificación + rollback | — |
| `scripts/boot-performance/*` | Scripts de gobernador + Wi-Fi e instaladores | — |
| `docs/` | Registro técnico completo del proceso de modificación | — |
| `SHA256SUMS` | Hashes de todas las imágenes | — |

## Requisitos

- Pantalla con SoC **AC8227L** (p. ej. familia Jancar 8227L).
- Acceso ADB a la unidad (el firmware de fábrica habilita Wi-Fi en el puerto 5555, o USB) con `su 0` (root) disponible — el firmware de fábrica lo permite.
- **Alimentación estable** durante el flash (que la unidad no se apague a mitad de escritura).
- Se recomienda encarecidamente hacer copia de tus propias particiones originales: los scripts verifican que coinciden con los hashes de fábrica de la unidad de prueba; si tu unidad trae otra revisión de fábrica, actualiza las constantes `stock_hash` y usa **tus propias** copias originales en `images/originals/`.

## Flashear (BOOTIMG + ARM2)

```sh
# 1) Subir las imágenes (fíjate en los nombres exactos que esperan los scripts)
adb -s <ip-unidad>:5555 push images/boot-r3-1391.img          /data/local/tmp/ibiza-boot-r3-1391.img
adb -s <ip-unidad>:5555 push images/arm2-camara-condicional-r3.bin /data/local/tmp/ibiza-arm2-r3.bin
adb -s <ip-unidad>:5555 push images/originals/boot-original.img /data/local/tmp/ibiza-boot-original.img
adb -s <ip-unidad>:5555 push images/originals/arm2-original.bin  /data/local/tmp/ibiza-arm2-original.bin
adb -s <ip-unidad>:5555 push scripts/flashear-boot-r3-1391.sh /data/local/tmp/flashear-boot-r3-1391.sh
adb -s <ip-unidad>:5555 push scripts/flashear-arm2-r3.sh      /data/local/tmp/flashear-arm2-r3.sh

# 2) Flashear BOOTIMG (verifica hardware, particiones, hashes; escribe; verifica; rollback si falla)
adb -s <ip-unidad>:5555 shell su 0 sh /data/local/tmp/flashear-boot-r3-1391.sh

# 3) Flashear ARM2 (mismas comprobaciones)
adb -s <ip-unidad>:5555 shell su 0 sh /data/local/tmp/flashear-arm2-r3.sh

# 4) Reiniciar
adb -s <ip-unidad>:5555 reboot
```

Ambos scripts usan el switch de protección de escritura por software del eMMC (`/sys/kernel/debug/mmc0/sw_wp_en`) y lo restauran al terminar. Si la verificación posterior falla, se reescribe la imagen original y se verifica automáticamente.

## Rendimiento de arranque (gobernador + Wi-Fi)

```sh
# Subir instaladores y payloads, y entonces:
adb -s <ip-unidad>:5555 shell su 0 sh /data/local/tmp/instalar-boot.sh            # gobernador desde early-boot
adb -s <ip-unidad>:5555 shell su 0 sh /data/local/tmp/instalar-wifi-arranque.sh   # servicio de Wi-Fi
# Para quitarlo después:
adb -s <ip-unidad>:5555 shell su 0 sh /data/local/tmp/desinstalar-boot.sh
```

## Restaurar a fábrica

Subir `images/originals/boot-original.img` y `arm2-original.bin` a `/data/local/tmp/` y hacer `dd` de vuelta:

```sh
su 0 sh -c 'echo 0 > /sys/kernel/debug/mmc0/sw_wp_en'
su 0 dd if=/data/local/tmp/ibiza-boot-original.img of=/dev/block/mmcblk0p10 bs=4096 count=4096
su 0 dd if=/data/local/tmp/ibiza-arm2-original.bin  of=/dev/block/mmcblk0p9  bs=4096 count=1024
su 0 sh -c 'sync; echo 1 > /sys/kernel/debug/mmc0/sw_wp_en'
```

Verificar con `sha256sum /dev/block/mmcblk0p10 /dev/block/mmcblk0p9` contra `SHA256SUMS`.

## SHA-256

| Fichero | SHA-256 |
|---|---|
| `images/boot-r3-1391.img` | `c5a00efe7ce94dfcdc2b1a0a73bb658ce287b5a6af5cf1704e15b5bda26f388a` |
| `images/arm2-camara-condicional-r3.bin` | `74933039931544fd57f86a21f2d3adb1e948b852e5db1f617751e85865e0752a` |
| `images/originals/boot-original.img` | `8911ad0e01bf9e229d76eeb5d43ee117e793553192458c69108c144dcd66dc57` |
| `images/originals/arm2-original.bin` | `679bb2274f50a9d2b99b840003284a9a7063674fd6fecc272d0652b25a6eba14` |
| `images/originals/recovery-original.img` | `c3d74deaf929eddc70f479a35577db5f3ff928f784e14d13e45d943d36eb5731` |

## Advertencias

- Flashear particiones de boot se hace **bajo tu propia responsabilidad**. Mantén la alimentación durante la operación.
- Las imágenes se construyeron a partir del firmware de fábrica de la unidad de prueba (Jancar 8227L, `JCAC10003-OC2-V1.1.80R6-251118_0756`) y se verificaron contra él. Si tu unidad corre otra revisión, las comprobaciones previas de hash detendrán los scripts: haz copia de tus particiones originales primero y ajusta las constantes `stock_hash`.
- El overclock a 1391 MHz es un paso del +7 % de frecuencia al voltaje de fábrica de 1300 mV; la unidad de prueba funcionó estable, pero el comportamiento térmico a largo plazo en otras unidades no está garantizado.
- Nada de este paquete modifica `/system`, `/vendor`, `/data` ni la partición de recovery.
