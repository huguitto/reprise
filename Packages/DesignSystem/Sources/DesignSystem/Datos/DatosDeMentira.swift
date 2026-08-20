import Foundation
import AlarmCore

/// Los datos con los que se pintan las pantallas estaticas.
///
/// Todo inventado. Ninguna pantalla del sistema de diseno habla con
/// persistencia, sensores ni red: eso es de los otros tres paquetes.
public enum DatosDeMentira {

    // MARK: - Alarmas

    public static let alarmas: [Alarm] = [
        Alarm(hour: 6, minute: 30,
              weekdays: [.lunes, .martes, .miercoles, .jueves, .viernes],
              challenge: .pasos, label: "Gimnasio", isEnabled: true),
        Alarm(hour: 7, minute: 15,
              weekdays: [.sabado],
              challenge: .sentadillas, label: "Correr", isEnabled: true),
        Alarm(hour: 9, minute: 0,
              weekdays: [.domingo],
              challenge: .pasos, label: "", isEnabled: false),
        Alarm(hour: 5, minute: 45,
              weekdays: [],
              challenge: .sentadillas, label: "Vuelo a Berlín", isEnabled: false)
    ]

    public static var proximaAlarma: Alarm { alarmas[0] }

    // MARK: - Tonos

    public static let tonos: [Tone] = [
        Tone(id: Tone.defaultID, nombre: "El del sistema", fileName: nil, isPro: false),
        Tone(id: "amanecer", nombre: "Amanecer", fileName: "amanecer.caf", isPro: false),
        Tone(id: "taller", nombre: "Taller", fileName: "taller.caf", isPro: true),
        Tone(id: "sirena", nombre: "Sirena", fileName: "sirena.caf", isPro: true),
        Tone(id: "campana", nombre: "Campana", fileName: "campana.caf", isPro: true)
    ]

    // MARK: - Racha

    public static let rachaActual = 12
    public static let mejorRacha = 28
    public static let vidasRestantes = 2

    public static let niveles: [Nivel] = [
        Nivel(numero: 1, nombre: "Te suena el despertador", desde: 0, hasta: 3),
        Nivel(numero: 2, nombre: "Te levantas", desde: 3, hasta: 7),
        Nivel(numero: 3, nombre: "Ya no cuesta tanto", desde: 7, hasta: 14),
        Nivel(numero: 4, nombre: "Constante", desde: 14, hasta: 30),
        Nivel(numero: 5, nombre: "Imparable", desde: 30, hasta: 60),
        Nivel(numero: 6, nombre: "Leyenda", desde: 60, hasta: nil)
    ]

    public static func nivel(paraRacha racha: Int) -> Nivel {
        niveles.last { racha >= $0.desde } ?? niveles[0]
    }

    public static let insignias: [FichaDeInsignia] = [
        FichaDeInsignia(id: "primera", simbolo: "sunrise.fill", nombre: "Primer día", conseguida: true),
        FichaDeInsignia(id: "semana", simbolo: "flame.fill", nombre: "7 seguidos", conseguida: true),
        FichaDeInsignia(id: "sinvidas", simbolo: "heart.slash.fill", nombre: "Mes sin vidas", conseguida: true),
        FichaDeInsignia(id: "relampago", simbolo: "bolt.fill", nombre: "Reto en 15 s", conseguida: true),
        FichaDeInsignia(id: "mes", simbolo: "crown.fill", nombre: "30 seguidos", conseguida: false),
        FichaDeInsignia(id: "invierno", simbolo: "snowflake", nombre: "Enero entero", conseguida: false)
    ]

    /// Agosto de 2026 hasta el dia 20, que es hoy en los datos de mentira.
    public static let mesDeEjemplo: [DayRecord] = {
        var registros: [DayRecord] = []
        // Ocho dias buenos, un tropiezo salvado por una vida, un fallo seco y
        // la racha de doce que se ensena arriba. Interesa que el calendario
        // tenga de todo: si solo hubiera dias verdes no se veria el diseno de
        // los otros estados.
        let desenlaces: [DayOutcome] = [
            .completado, .completado, .completado, .fallado(.ignorada),
            .completado, .completado, .salvadoPorVida(.paroSinReto), .completado,
            .completado, .completado, .completado, .completado,
            .completado, .completado, .completado, .completado,
            .completado, .completado, .completado, .completado
        ]
        for (indice, desenlace) in desenlaces.enumerated() {
            registros.append(DayRecord(
                day: Day(year: 2026, month: 8, day: indice + 1),
                alarmID: proximaAlarma.id,
                challenge: .pasos,
                outcome: desenlace,
                duration: 34
            ))
        }
        return registros
    }()

    public static let hoy = Day(year: 2026, month: 8, day: 20)

    // MARK: - Ranking

    public static let rankingMundial: [PuestoDeRanking] = [
        PuestoDeRanking(posicion: 1, nombre: "keiko_ohara", bandera: "🇯🇵", racha: 214),
        PuestoDeRanking(posicion: 2, nombre: "mattias.l", bandera: "🇸🇪", racha: 198),
        PuestoDeRanking(posicion: 3, nombre: "adaeze", bandera: "🇳🇬", racha: 187),
        PuestoDeRanking(posicion: 4, nombre: "tomas_bruno", bandera: "🇧🇷", racha: 152),
        PuestoDeRanking(posicion: 5, nombre: "leonor.ruiz", bandera: "🇪🇸", racha: 149),
        PuestoDeRanking(posicion: 6, nombre: "dmitri_k", bandera: "🇩🇪", racha: 141),
        PuestoDeRanking(posicion: 7, nombre: "farah", bandera: "🇲🇦", racha: 137),
        PuestoDeRanking(posicion: 8, nombre: "n.esposito", bandera: "🇮🇹", racha: 130)
    ]

    public static let rankingDeEspana: [PuestoDeRanking] = [
        PuestoDeRanking(posicion: 1, nombre: "leonor.ruiz", bandera: "🇪🇸", racha: 149),
        PuestoDeRanking(posicion: 2, nombre: "jandro_87", bandera: "🇪🇸", racha: 96),
        PuestoDeRanking(posicion: 3, nombre: "marina.gil", bandera: "🇪🇸", racha: 74),
        PuestoDeRanking(posicion: 4, nombre: "el_pau", bandera: "🇪🇸", racha: 61),
        PuestoDeRanking(posicion: 5, nombre: "carmen_v", bandera: "🇪🇸", racha: 58),
        PuestoDeRanking(posicion: 6, nombre: "borja.mtz", bandera: "🇪🇸", racha: 44),
        PuestoDeRanking(posicion: 7, nombre: "sara__k", bandera: "🇪🇸", racha: 39),
        PuestoDeRanking(posicion: 8, nombre: "nachete", bandera: "🇪🇸", racha: 31)
    ]

    public static let tuPuestoMundial = PuestoDeRanking(
        posicion: 4318, nombre: "tu", bandera: "🇪🇸", racha: rachaActual, eresTu: true
    )

    public static let tuPuestoEnEspana = PuestoDeRanking(
        posicion: 271, nombre: "tu", bandera: "🇪🇸", racha: rachaActual, eresTu: true
    )

    // MARK: - Pro

    public static let ventajasPro: [(simbolo: String, texto: String)] = [
        ("alarm.waves.left.and.right.fill", "Alarmas ilimitadas, no una"),
        ("music.note.list", "El catálogo de tonos entero"),
        ("chart.bar.fill", "Estadísticas e histórico completo"),
        ("flag.fill", "Ranking filtrado por país"),
        ("rosette", "Insignias y temas exclusivos"),
        ("dial.high.fill", "Subir la dificultad del reto")
    ]
}
