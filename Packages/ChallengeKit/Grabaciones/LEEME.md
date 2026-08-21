# Grabaciones de calibracion

Aqui viven las grabaciones reales con las que se calibran los dos detectores.
Salen de `CalibracionView` y se sacaron del iPhone con:

```bash
xcrun devicectl device copy from --device <uuid> \
  --domain-type appDataContainer --domain-identifier com.hrocha.reprise \
  --user mobile --source Documents/Grabaciones --destination .
```

En cuanto haya ficheros en esta carpeta, `swift test` los reproduce y comprueba
que el detector cuenta lo que la persona dijo que hizo. **Ese es el bucle de
trabajo**: dejas caer una grabacion, corres los tests, ves el numero. Sin salir
del Mac y sin volver a hacer sentadillas ni a andar por el pasillo.

## Que hay grabado

- **2 sesiones** de 10 sentadillas, mano derecha, una sola persona. Las dos
  cuentan 10 de 10.
- **3 sesiones de 20 pasos**, andando con el movil en la mano (21/08/2026), de
  las que valen dos:
  - `...-213421-...`, andando despacio (1,2 pasos/s): cuenta **20 de 20**.
  - `...-215040-...`, andando deprisa (1,5 pasos/s): cuenta **23 de 20**.
  - `...-213243-...` esta marcada `descartada-...` en su etiqueta porque quien la
    grabo dijo que no valia, y los tests la saltan: una grabacion cuyo numero
    real no es de fiar es peor que ninguna, porque tira de los umbrales sin que
    se note. El fichero se queda por si algun dia se sabe que le paso.
- **2 trampas** (agitar el movil sentado). Contra las sentadillas se quedan en 3.
  Contra los pasos, en **7 y 5 de 20**.

**Lo que estas grabaciones zanjaron.** Andar con el movil en la mano es una senal
mucho mas debil de lo que nadie habia supuesto: andando despacio el pico crudo no
pasa de **3,9 m/s^2** (1,8 filtrado). La trampa, a la misma frecuencia exacta
—1,30 Hz las dos cosas—, llega a **18,9** filtrado. Antes de tener esto, el techo
anti-trampa se defendia de una "pisada fuerte" de 12-20 m/s^2 que **no existe**,
y para no romperla se habia añadido un parametro entero al algoritmo. Se quito el
mismo dia que llegaron los ficheros.

**Y lo que zanjo la tercera, andando deprisa.** Que dos caminatas de la misma
persona no son un abanico: andar deprisa mas que duplica la fuerza (8,85 crudos,
5,5 filtrados). Bastaba eso para que la eleccion de umbrales que clavaba las dos
primeras se cayera. De ahi salio la regla de esta carpeta: **nunca afinar hasta
clavar el numero de las grabaciones que hay**. El test
`laMismaCaminataMasFuerteSigueContando` coge la senal real y le sube el volumen,
que es lo que cambia de una persona a otra, y no deja apretar.

**Y lo que enseño la cuarta, la muneca.** Grabada porque Hugo vio el contador
subir de pie, sin moverse del sitio. Es la que rompio la idea de que esto se
arreglaba con umbrales de fuerza: mover la muneca da 1-3 m/s^2, dentro de lo que
anda una persona, y contaba **16 pasos en 12 segundos**. La separa el **giro del
movil** —cuanto pivota el vector gravedad— y solo eso: andando son 3-57 deg/s,
moviendo la muneca 52-173. Con el techo en 60 las tres trampas pasan de 4, 7 y 16
a 0, 2 y 1, y las caminatas no pierden **ni un paso**. De paso enterro el
discriminador que las notas daban por bueno desde el principio, el ritmo: la
trampa sale mas regular que la caminata.

Esa grabacion enseño otra cosa, que no es del algoritmo. En pantalla marcaba
"1" y por eso parecia que no habia fallo: la vista de calibracion enseñaba el
contador de **sentadillas** cuando el tipo era trampa. Una herramienta de medir
que enseña el numero del otro reto convence de que no hay nada que arreglar.
Arreglado: grabando una trampa ahora salen los dos contadores.

**Lo que sigue faltando:** una caminata con el **brazo colgando y balanceando**
—las tres que hay son sujetando el movil delante, y el brazo hace pivotar el
telefono mucho mas, que es justo lo que ahora veta el techo de giro—, una de
**otra persona**, y una de alguien corriendo o subiendo escaleras. El banco sintetico (`EstresDePasosTests`) tapa el
hueco mientras tanto, pero es senal inventada: donde las dos fuentes discrepen,
mandan los ficheros.

Lo que el encargo pedia para las sentadillas y no se llego a grabar: cinco
sesiones en vez de dos, mano izquierda, y personas de estatura distinta.

**Estos ficheros no se pueden volver a generar tal cual estan**, asi que borrar
algo de esta carpeta es irreversible, y hay un test que lo vigila.

## Por que en el repositorio y no solo en el movil

Porque un umbral elegido sin poder repetir la medida no es un umbral, es una
opinion. Con los ficheros aqui, cualquiera puede cambiar un parametro y ver al
instante a quien deja de contarle sus sentadillas o sus pasos. El issue #35
—sesenta pasos para que contara veinte— vivio dos intentos de arreglo porque el
que contaba era `CMPedometer` y no habia forma de mirarle dentro.
