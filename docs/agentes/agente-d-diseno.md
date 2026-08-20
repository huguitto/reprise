# Agente D — Sistema de diseno

**Worktree**: `../wt-diseno` · **Rama**: `feat/sistema-diseno`
**Paquete tuyo**: `DesignSystem`, mas las pantallas estaticas

Eres el unico que no depende de nadie. Puedes ir a fondo desde el minuto uno.

## La direccion

`docs/design/referencias/01-reloj-fisico-direccion-principal.png` es **la**
referencia: reloj fisico blanco, superficies neumorficas, digitos de matriz de
puntos, base monocroma y **un solo color de acento**. La 02 aporta el uso
editorial de la tipografia y el numero gigante como protagonista.

Las referencias **03 y 04 estan descartadas** (oscuro con verde neon, tarjetas
redondeadas). Estan en la carpeta solo para que sepas que se miraron y se
rechazaron por genericas. No las mezcles: quedaria a medio camino y sin caracter.

## Entregables

**Sistema**: tokens de color, tipografia, espaciado y elevacion; los digitos de
matriz de puntos; las superficies neumorficas; el dial de "Off"; botones, campos y
selectores de dias.

**Pantallas** (estaticas, con datos de mentira): lista de alarmas · crear y editar
alarma · **el reto en curso** · racha con niveles e insignias · ranking mundial y
por paises · ajustes · muro de pago.

## Dos reglas por encima de la estetica

1. **La pantalla del reto se usa a las 6 de la manana, a oscuras y con los ojos a
   medio abrir.** Ahi el contraste manda sobre la sutileza: contador enorme,
   legible de un vistazo, nada de grises sobre grises. El neumorfismo es precioso
   y funciona con contrastes bajisimos — en esa pantalla concreta, subelo.
2. **Modo claro principal, modo oscuro real.** El oscuro no es un afterthought: es
   literalmente cuando se usa la app.

Todos los textos en espanol.

## Terminado cuando

- Cada pantalla tiene su `#Preview` en claro y en oscuro.
- Se ve bien en el iPhone del usuario, que puede instalar con cuenta gratuita de
  Apple: no necesitas esperar a nada.
- Nada tuyo importa `AlarmKit` ni `CoreMotion`. Si lo necesitas, es que estas
  haciendo el trabajo de otro.

## Lo que NO haces

Logica de rachas, sensores ni red. Datos falsos y a correr.
