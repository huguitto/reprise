import SwiftUI
import AlarmCore
import DesignSystem

@main
struct RepRiseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Andamio. La pantalla real la monta el agente D sobre el sistema de diseno.
struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("RepRise")
                .font(.largeTitle.weight(.heavy))
            Text("Fase 0 — andamio")
                .foregroundStyle(.secondary)
        }
        .tint(DesignSystem.acento)
    }
}
