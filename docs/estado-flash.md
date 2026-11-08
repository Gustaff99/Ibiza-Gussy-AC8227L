# Preparación de firmware — Ibiza Gussy

Estado: investigación, copias y candidato de laboratorio; **no existe una imagen validada ni lista para flashear**.

## Revisión r3

- `boot-r3-1300-LAB-NO-FLASHEAR.img` conserva los 1 300 000 kHz en la rama de calibración de la unidad. `boot-r3-1391-LAB-NO-FLASHEAR.img` contiene el mismo kernel y añade `ibiza.oc=1391` al encabezado de arranque. Al arrancar, el controlador lee la línea de comandos real y selecciona el límite y la entrada de la tabla juntos. Las demás ramas de calibración no se modifican. El voltaje nominal de la entrada se conserva en 1300 mV. La opción se elige al preparar el boot, no desde el menú Android. Queda por comprobar que LK transmite el parámetro del encabezado y medir el reloj efectivo y la estabilidad.
- `arm2-camara-condicional-r3-LAB-NO-FLASHEAR.bin` es una imagen separada. Usa la orden APP_READY original del kernel. En el bucle de cámara de ARM2, después del escaneo inicial del decodificador, conserva el traspaso normal si hay vídeo. Si Android ya anunció que estaba listo, la marcha sigue activa y tanto el estado de señal actualizado como la lectura nueva indican ausencia, activa la ruta original de parada. Una orden explícita FORCE_STOP conserva su semántica original. No cambia el formato del vídeo ni configura el TP9950 durante el arranque temprano.
- `probar-r3.py` ejecuta el código ARM real del punto de selección del reloj y del traspaso en Unicorn. Verifica las dos frecuencias, que coincidencias parciales no activan el overclock, el identificador de Android y las 16 combinaciones de disponibilidad, marcha y señal, con las lecturas del sensor simuladas. También comprueba las respuestas del manejador original para los mensajes 2 y 3. `probar-descompresor-arm.py` verifica ambas imágenes con la rutina de descompresión original.
- `crear-r3.py` valida las dos copias de fábrica por SHA-256 y genera el perfil de 1,3 GHz por defecto. `--overclock` genera el perfil opcional. El firmware de cámara es idéntico para ambos perfiles. Siguen pendientes la aceptación de las imágenes por el cargador y la prueba de vídeo y frecuencia en la pantalla.

## Revisión r2

- `boot-1391-traspaso-r2-LAB-NO-FLASHEAR.img` reúne las dos modificaciones. `boot-1391-r2-LAB-NO-FLASHEAR.img` permite aislar el cambio de frecuencia. Las variantes anteriores conservaban el identificador SHA-1 de Android de la imagen de fábrica. La r2 lo recalcula y coloca un único miembro gzip válido en el espacio original, con el tamaño descomprimido al final. La cabecera MediaTek, el ramdisk y la disposición de los segmentos se conservan.
- `probar-descompresor-arm.py` ejecutó las instrucciones de reubicación y descompresión del zImage original con Unicorn. El original y las dos variantes r2 produjeron exactamente los 15 282 176 bytes esperados en cada caso. `probar-candidatos-offline.py` comprobó también el identificador de Android, la frecuencia, los cambios binarios y el mensaje elegido.
- El binario de **esta unidad** distingue APP_READY de FORCE_STOP en la función ARM2 situada a 0xf9a4 desde el comienzo del código. La emulación de esa función, con el registro y el envío al buzón interceptados, confirma que ambas órdenes solicitan ceder el control y que la 3 activa además una bandera. El código de lectura GPIO de ARM2 consulta esa bandera y devuelve marcha atrás desactivada a su propio hilo. Con el hilo activo, la función de mensajes delega la respuesta y no la envía inmediatamente. Queda por medir si Android toma la imagen manteniendo la marcha engranada. La r2 no cambia el decodificador temprano.
- El kernel original contiene la entrada de 1 391 000 kHz a 1 300 mV y la usa en otra rama de calibración. La tabla de potencia calcula el consumo a partir de las frecuencias de la tabla. Su regla especial para configuraciones de dos y tres núcleos a 1 300 000 kHz se conserva, tal como ocurre en el nivel original de 1 391 000 kHz. La estabilidad y temperatura de esta unidad siguen pendientes de medición.
- Tras el ramdisk alineado hay un bloque de 256 bytes de origen no identificado. La r2 lo conserva. El identificador SHA-1 de Android no lo sustituye ni verifica. Falta comprobar si el cargador exige una firma para aceptar la imagen.

Identificación observada: AC8227L, firmware `JCAC10003-OC2-V1.1.80R6-251118_0756`, kernel `3.18.79+`.

Copias leídas desde esta unidad y comprobadas con SHA-256 frente a sus particiones actuales:

- `boot-original.img`, 16 777 216 bytes, SHA-256 `8911ad0e01bf9e229d76eeb5d43ee117e793553192458c69108c144dcd66dc57`.
- `recovery-original.img`, 16 777 216 bytes, SHA-256 `c3d74deaf929eddc70f479a35577db5f3ff928f784e14d13e45d943d36eb5731`.
- `arm2-original.bin`, 4 194 304 bytes, SHA-256 `679bb2274f50a9d2b99b840003284a9a7063674fd6fecc272d0652b25a6eba14`.

Las copias de BOOTIMG y RECOVERY se habían creado antes; ARM2 se ha copiado en esta revisión. Que coincidan bit a bit no prueba que exista un método de restauración funcional ni que el equipo pueda recuperarse tras un fallo.

## Límites pendientes

- El controlador de CPU expone 598000, 747500, 1040000, 1196000 y 1300000 kHz. No se dispone de una tabla superior verificada para esta placa ni de un kernel modificado probado.
- ARM2 muestra indicios de una ruta CVBS/TVD; la ruta de Android usa el decodificador TP9950 y está configurada para AHD 720p/25. No está probado qué cambios permitirían imagen AHD en el firmware temprano.
- La captura `../camara-arranque-diagnostico.txt` registra que la cesión de ARM2 a Android tardó hasta que cambió el estado de marcha atrás durante la prueba. Esto no identifica aún la corrección.
- No se ha comprobado conexión USB de datos al PC, modo de recuperación ni restauración externa. El nombre de una plataforma o una imagen de otra placa no acredita compatibilidad.

## Trabajo exploratorio posterior

- Fuente pública `iscle/android_kernel_autochips_ac8227l`, commit `947d777300b2d6534d947254bc1c550df242e281`, Linux 3.18.119; la unidad usa 3.18.79+. El árbol contiene una tabla de 1 391 000 kHz, pero no se han encontrado las fuentes del controlador `tp9950_yuv` ni del subsistema de marcha atrás de Autochips.
- Al importar la configuración real y ejecutar `olddefconfig`, desaparecen opciones presentes en el kernel de la unidad, como `CONFIG_ATC_BACKCAR` y `CONFIG_ARCH_AC8227L`; por ello el árbol no reconstruye fielmente el kernel original.
- `investigacion-1391-no-flashear.patch` es un diff de investigación sobre el árbol público, no un firmware. Cambia la tabla y límite del nivel 0 a 1 391 000 kHz, sin probar calibración, estabilidad, límites térmicos reales o compatibilidad de esta placa. No corrige ARM2.
- La compilación de referencia con GCC ARM 4.8 y la configuración original importada ha encontrado errores por archivos ausentes: `mach/upmu_sw.h`, `drivers/input/keyboard/mediatek/ac8227l/Makefile` y `hal_kpd.h`. Se interrumpió tras detectarlos; detalles en `errores-kernel-base.txt`. `olddefconfig` eliminó opciones de plataforma y cámara de la unidad.
- El controlador de frecuencia modificado sí compiló como objeto ARM aislado usando la configuración genérica `mt8127` del árbol público y cabeceras de esa plataforma. Se ha guardado como `mt_cpufreq-investigacion-1391-no-flashear.o`. Esto valida sintaxis y compilación aislada únicamente: no es un módulo instalable, no es una imagen y no prueba compatibilidad, estabilidad ni comportamiento térmico. Registro en `compilacion-cpufreq-lab.txt`.

## Candidato binario de laboratorio, no flashear

`boot-1391-LAB-NO-FLASHEAR.img` parte de la copia original de esta unidad y pretende cambiar la tabla de frecuencia del nivel 0 y el límite de inicialización de 1 300 000 a 1 391 000 kHz. `crear-boot-laboratorio.py` comprueba la copia original, firmas binarias y recompresión; el resultado se ha descomprimido independientemente y se ha comprobado que cambian siete bytes del kernel sin comprimir y se conservan los bytes del boot fuera del segmento comprimido. El informe `boot-1391-LAB-informe.json` recoge las huellas.

Es un experimento estático: no se ha probado el arranque, la compatibilidad del empaquetado con el cargador, la estabilidad, el voltaje, el comportamiento térmico ni el resto de límites del controlador. No se ha acreditado que este chip del nivel 0 admita la frecuencia de otro nivel de calibración. No modifica ARM2 ni arregla la cámara. **No es una imagen lista para instalar.**

`boot-1391-traspaso-LAB-NO-FLASHEAR.img` es una segunda variante de investigación sobre la misma copia original. Además del experimento de frecuencia sustituye, al recibir `IOCTL_FSC_NOTIFY_APP_READY`, el mensaje 2 al coprocesador por el mensaje 3 que el mismo kernel usa para solicitar la parada de ARM2. El cambio estático conserva las zonas ajenas al kernel comprimido, se puede descomprimir y la instrucción ARM modificada ejecuta `mov r0, #3` en un emulador. `probar-candidatos-offline.py` verifica esas propiedades y el límite de frecuencia de ambas variantes.

La semántica real del firmware ARM2 para el mensaje 3 no se ha observado en esta unidad. No hay prueba de que conteste, libere vídeo de forma segura ni permita mostrar la imagen sin una nueva señal de marcha atrás. Este candidato no añade soporte AHD al ARM2 y **tampoco es una versión final ni está listo para flashear**. Las pruebas estáticas y la emulación de unas instrucciones no equivalen a arrancar el equipo ni a probar la cámara.

## Investigación posterior de la cámara

- Se ha comparado la configuración de cámara de esta unidad con el `iviconfig.zip` extraído y comprobado por CRC de un paquete público atribuido a la misma compilación `251118_0756`. Los valores `BackCarVideoSource` de ambos archivos de configuración coinciden; su discrepancia entre archivos no demuestra un defecto. La procedencia y compatibilidad completa del paquete no están verificadas.
- La documentación y el código de LibreHU para una Jancar AC8257 identifican ajustes persistentes de cámara en metazone y describen una ruta de cámara temprana AHD. Son una pista útil, pero los valores de otra plataforma no deben escribirse en esta AC8227L sin leer y comprobar primero su implementación y configuración reales. Fuente: https://github.com/LibreHU/LibreHU-service/blob/main/docs/atc.md y https://github.com/LibreHU/android_kernel_autochips_ac8257_4.9/blob/LibreHU-main/docs/VIDEO.md
- En la AC8257 citada se evita forzar la cesión mientras marcha atrás está activa; esto aumenta la incertidumbre sobre el parche experimental que reemplaza APP_READY por STOP_ARM2. El registro propio no demuestra que STOP_ARM2 produzca la respuesta esperada. Mantener la variante marcada NO FLASHEAR.

- Se extrajeron los símbolos embebidos del kernel original en `kallsyms-original.txt` y se desensambló `backcar_ioctl` en `desensamblado-backcar.txt`.
- En el código GPL publicado para AC8257 por LibreHU, `IOCTL_BC_FORCE_STOP_ARM2` solicita a ARM2 que termine la vista temprana y `IOCTL_FSC_NOTIFY_APP_READY` solicita el traspaso normal. Es otra plataforma, no un binario compatible.
- El kernel original AC8227L contiene una rama para el comando `0x80044d15` que envía el mensaje 3 mediante `backcar_send_message`; también contiene el comando `0x80044d01`, cuyo camino envía el mensaje 2. Esto es coherente con el mecanismo descrito por el código AC8257, pero no demuestra que ARM2 vaya a liberar la cámara correctamente en esta unidad.
- El registro de la prueba muestra que el traspaso normal esperó mientras la marcha atrás permanecía conectada. La posible orden de parada forzada se mantiene solo como hipótesis; no se ha ejecutado ni modificado la cámara o ARM2. Hay que evaluar la transición de imagen y la seguridad antes de cualquier ensayo.

No escribir las copias ni otros archivos en las particiones como prueba. La restauración necesita validarse con un método específico y acceso físico antes de que pueda considerarse recuperable.
