# Grabaciones de calibracion

Aqui van los `.json` que salen de la pantalla de calibracion (`CalibracionView`),
exportados desde el iPhone con el boton de compartir.

En cuanto haya ficheros en esta carpeta, `swift test` los reproduce y comprueba
que el detector cuenta lo que la persona dijo que hizo. **Ese es el bucle de
trabajo**: dejas caer una grabacion, corres los tests, ves el numero. Sin salir
del Mac y sin volver a hacer sentadillas.

## Que hace falta grabar

El criterio de terminado del encargo pide, como minimo:

- **Cinco sesiones distintas** de 10 sentadillas que cuenten exactamente 10.
- Con el movil en la **mano derecha** y en la **izquierda**.
- Con **personas de estatura distinta**.
- Y al menos una de tipo `trampa`: agitar el movil sentado en la cama, que tiene
  que quedarse por debajo de 10.

Pon eso en el campo *etiqueta* al grabar, que es lo unico que despues distingue
una grabacion de otra.

## Por que en el repositorio y no solo en el movil

Porque un umbral elegido sin poder repetir la medida no es un umbral, es una
opinion. Con los ficheros aqui, cualquiera puede cambiar un parametro y ver al
instante a quien deja de contarle sus sentadillas.
