import SwiftUI
import AppKit

// keepawake-menubar — versione moderna con MenuBarExtra (macOS 13+).
// Su macOS 26 (Tahoe) NSStatusItem viene creato ma piazzato fuori schermo
// (screen=nil): MenuBarExtra e' l'API corretta e registra l'item in barra.

@MainActor
final class KeepAwakeModel: ObservableObject {
    @Published var active = false

    init() {
        refresh()
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["-g"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            p.waitUntilExit()
            var state = 0
            for line in text.split(separator: "\n") {
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).filter { !$0.isEmpty }
                if parts.count >= 2, parts[0] == "SleepDisabled" {
                    state = String(parts[1]) == "1" ? 1 : 0
                }
            }
            active = (state == 1)
        } catch {
            log("pmset errore: \(error)")
        }
    }

    func toggle() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/Users/simone/.local/bin/keepawake-toggle")
        try? p.run()
        p.waitUntilExit()
        refresh()
    }
}

@main
struct KeepAwakeApp: App {
    @StateObject private var model = KeepAwakeModel()

    var body: some Scene {
        MenuBarExtra {
            Button(action: { model.toggle() }) {
                Text(model.active ? "Disattiva KeepAwake (F5)" : "Attiva KeepAwake (F5)")
            }
            Divider()
            Text(model.active ? "⚡️ Stato: ATTIVO — il Mac non dorme" : "☕️ Stato: spento — sonno normale")
            Divider()
            Button("Esci") { NSApp.terminate(nil) }
        } label: {
            Text(model.active ? "⚡️" : "")
        }
        .menuBarExtraStyle(.menu)
    }
}

let LOGPATH = "/tmp/keepawake-menubar.log"
func log(_ msg: String) {
    let line = "\(Date()) \(msg)\n"
    if let data = line.data(using: .utf8),
       let h = FileHandle(forWritingAtPath: LOGPATH) {
        h.seekToEndOfFile()
        h.write(data)
    } else {
        try? line.write(toFile: LOGPATH, atomically: false, encoding: .utf8)
    }
}
