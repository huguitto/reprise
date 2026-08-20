import Foundation
import AlarmCore

#if os(iOS)
import AVFoundation

/// El sonido de la alarma mientras la app esta delante haciendo el reto.
///
/// Cuando el usuario pulsa el boton secundario, la alerta de AlarmKit se cierra
/// y con ella se va su sonido. A partir de ahi el ruido lo pone la app, y esta
/// es la pieza que lo pone: en bucle, por encima del interruptor de silencio, y
/// sin callarse hasta que alguien lo diga.
actor ChallengeSound {
    private var reproductor: AVAudioPlayer?
    private var motor: AVAudioEngine?
    private var nodo: AVAudioPlayerNode?

    private(set) var isPlaying = false

    /// Empieza a sonar, o sigue sonando si ya estaba.
    func start(tone: Tone, bundle: Bundle) {
        guard !isPlaying else { return }
        prepararSesion()

        if let fileName = tone.fileName,
           let url = ToneCatalog.url(deFichero: fileName, en: bundle),
           let reproductor = try? AVAudioPlayer(contentsOf: url) {
            reproductor.numberOfLoops = -1
            reproductor.volume = 1
            reproductor.prepareToPlay()
            reproductor.play()
            self.reproductor = reproductor
            isPlaying = true
            return
        }

        arrancarPitido()
    }

    func stop() {
        reproductor?.stop()
        reproductor = nil
        nodo?.stop()
        nodo = nil
        motor?.stop()
        motor = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func prepararSesion() {
        let sesion = AVAudioSession.sharedInstance()
        // `.playback` es la unica categoria que ignora el interruptor de
        // silencio. Sin esto, la mitad de los usuarios no oiria nada.
        try? sesion.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? sesion.setActive(true)
    }

    /// Respaldo cuando el tono es el del sistema o el fichero no esta: iOS no
    /// nos presta su sonido de alarma, asi que generamos uno.
    ///
    /// PROVISIONAL: en cuanto haya un fichero de tono por defecto en el bundle,
    /// esto deberia dejar de sonar nunca.
    private func arrancarPitido() {
        let motor = AVAudioEngine()
        let nodo = AVAudioPlayerNode()
        motor.attach(nodo)
        guard let formato = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
              let buffer = Self.pitido(formato: formato)
        else { return }

        motor.connect(nodo, to: motor.mainMixerNode, format: formato)
        motor.prepare()
        guard (try? motor.start()) != nil else { return }

        nodo.scheduleBuffer(buffer, at: nil, options: .loops)
        nodo.play()

        self.motor = motor
        self.nodo = nodo
        isPlaying = true
    }

    /// Medio segundo de tono y un respiro, para repetir en bucle.
    private static func pitido(formato: AVAudioFormat) -> AVAudioPCMBuffer? {
        let muestreo = formato.sampleRate
        let segundosDeTono = 0.45
        let segundosDeSilencio = 0.35
        let frecuencia = 880.0
        let total = AVAudioFrameCount((segundosDeTono + segundosDeSilencio) * muestreo)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: total),
              let canal = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = total

        let muestrasDeTono = Int(segundosDeTono * muestreo)
        let rampa = 0.01 * muestreo  // 10 ms para que no chasquee al entrar y salir
        for i in 0..<Int(total) {
            guard i < muestrasDeTono else { canal[i] = 0; continue }
            let entrada = min(1, Double(i) / rampa)
            let salida = min(1, Double(muestrasDeTono - i) / rampa)
            let amplitud = 0.9 * entrada * salida
            canal[i] = Float(amplitud * sin(2 * .pi * frecuencia * Double(i) / muestreo))
        }
        return buffer
    }
}
#endif
