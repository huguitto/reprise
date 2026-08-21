# Grabaciones de calibracion

Aqui viven las grabaciones reales con las que se calibro el detector de
sentadillas. Salen de `CalibracionView` y se sacaron del iPhone con:

```bash
xcrun devicectl device copy from --device <uuid> \
  --domain-type appDataContainer --domain-identifier com.hrocha.reprise \
  --user mobile --source Documents/Grabaciones --destination .
```

En cuanto haya ficheros en esta carpeta, `swift test` los reproduce y comprueba
que el detector cuenta lo que la persona dijo que hizo. **Ese es el bucle de
trabajo**: dejas caer una grabacion, corres los tests, ves el numero. Sin salir
del Mac y sin volver a hacer sentadillas.

## Que hay grabado, y que falta

Cerrado el 21 de agosto de 2026 con tres ficheros, por debajo de lo que pedia el
encargo. Lo que hay:

- **2 sesiones** de 10 sentadillas, mano derecha, una sola persona. Las dos
  cuentan 10 de 10 con `.porDefecto`.
- **1 trampa** (agitar el movil sentado): se queda en 3, no llega al objetivo.

Lo que el encargo pedia y no se llego a grabar: cinco sesiones en vez de dos,
mano izquierda, y personas de estatura distinta.

**Estos ficheros no se pueden volver a generar tal cual estan.** La calibracion
ya no cuelga de la app —se quito de `RepRiseApp.swift` el mismo dia—, asi que
para grabar mas hay que recolgar `CalibracionView` desde el target. Borrar algo
de esta carpeta es irreversible, y hay un test que lo vigila.

## Por que en el repositorio y no solo en el movil

Porque un umbral elegido sin poder repetir la medida no es un umbral, es una
opinion. Con los ficheros aqui, cualquiera puede cambiar un parametro y ver al
instante a quien deja de contarle sus sentadillas.
