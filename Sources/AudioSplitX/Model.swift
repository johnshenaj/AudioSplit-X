import AppKit
import AudioCore
import Combine
import CoreAudio

struct Preference: Codable, Equatable {
    var name: String = ""
    var output: String = ""
    var volume: Float = 1
    var muted = false
    var needsRoute: Bool { !output.isEmpty || volume != 1 || muted }
}
struct Row: Identifiable {
    let id: String
    let name: String
    let pid: pid_t
    let playing: Bool
    let processes: [AudioObjectID]
    let status: String
    let diagnostics: String
    let peak: Float
    let active: Bool
}

// All HAL lifecycle operations live on one serial worker, never the UI thread.
final class RoutingWorker: @unchecked Sendable {
    private var engines: [String: RouteEngine] = [:]
    private var failures: [String: String] = [:]
    private var began: [String: Date] = [:]
    private var seenEnergy: Set<String> = []
    func stop() { engines.values.forEach { $0.stop() }; engines.removeAll(); began.removeAll(); seenEnergy.removeAll() }
    func retry() { failures.removeAll() }
    func snapshot(preferences: [String: Preference], enabled: Bool) -> ([AudioDevice], [Row], String) {
        let devices = AudioDevices.outputs()
        let groups = AudioProcesses.groups().filter { $0.bundleID != Bundle.main.bundleIdentifier && !$0.isSystemProcess }
        let defaultUID = AudioDevices.defaultOutput()?.uid ?? ""
        let keys = Set(groups.map(\.key))
        for key in Array(engines.keys) where !enabled || !keys.contains(key) || !(preferences[key]?.needsRoute ?? false) {
            engines.removeValue(forKey: key)?.stop(); began[key] = nil; seenEnergy.remove(key)
        }
        var rows: [Row] = []
        for group in groups {
            let p = preferences[group.key] ?? Preference(name: group.name)
            let uid = p.output.isEmpty ? defaultUID : p.output
            let target = devices.first { $0.uid == uid }
            var detail = ""
            var status = enabled ? "Uscita gestita dall’app / sistema" : "Routing sospeso"
            if enabled && p.needsRoute {
                if target == nil {
                    engines.removeValue(forKey: group.key)?.stop()
                    status = "Uscita scollegata: audio originale ripristinato"
                } else {
                    if let e = engines[group.key], e.outputDeviceUID != uid || e.processObjectIDs != group.processObjectIDs {
                        e.stop(); engines[group.key] = nil; began[group.key] = nil; seenEnergy.remove(group.key)
                        failures[group.key] = nil
                    }
                    if engines[group.key] == nil && failures[group.key] == nil {
                        let e = RouteEngine(label: group.name, processObjectIDs: group.processObjectIDs, outputDeviceUID: uid)
                        e.diagnosticsEnabled = true
                        e.volume = p.volume; e.isMuted = p.muted
                        do { try e.start(); engines[group.key] = e; began[group.key] = group.isPlaying ? Date() : nil }
                        catch { failures[group.key] = "Avvio fallito: \(error)" }
                    }
                    if let e = engines[group.key] {
                        e.volume = p.volume; e.isMuted = p.muted
                        if !group.isPlaying { began[group.key] = nil }
                        else if began[group.key] == nil { began[group.key] = Date() }
                        let d = e.diagnostics
                        detail = "callbacks=\(d.ioProcCalls), tap=\(d.tapFormat), output=\(d.outputFormat), rawPeak=\(d.rawInputPeak), bail=\(d.bailReason)"
                        if d.rawInputPeak > 0.00001 { seenEnergy.insert(group.key) }
                        status = seenEnergy.contains(group.key) ? "Segnale ricevuto → \(target!.name)" : "Percorso avviato; in attesa di segnale"
                        if p.muted { status += " · mute" }
                        // A successful HAL call alone is not proof of capture permission or audio.
                        if group.isPlaying && !seenEnergy.contains(group.key), let start = began[group.key], Date().timeIntervalSince(start) > 15 {
                            e.stop(); engines[group.key] = nil
                            failures[group.key] = "Nessun segnale rilevato: percorso fermato. Controlla permesso e riproduzione, poi Riprova."
                        }
                    }
                    if let error = failures[group.key] { status = error }
                }
            } else { failures[group.key] = nil }
            let peak = engines[group.key].map { max($0.levels.left, $0.levels.right) } ?? 0
            rows.append(Row(id: group.key, name: group.name, pid: group.pid, playing: group.isPlaying, processes: group.processObjectIDs, status: status, diagnostics: detail, peak: peak, active: engines[group.key] != nil))
        }
        for (key, p) in preferences where !keys.contains(key) && p.needsRoute {
            rows.append(Row(id: key, name: p.name, pid: 0, playing: false, processes: [], status: "App non presente tra i processi audio; preferenza salvata", diagnostics: "", peak: 0, active: false))
        }
        return (devices, rows, AudioDevices.defaultOutput()?.name ?? "Nessuna")
    }
}

@MainActor final class Model: ObservableObject {
    @Published var devices: [AudioDevice] = []
    @Published var rows: [Row] = []
    @Published var preferences: [String: Preference] = [:]
    @Published var enabled = true
    @Published var defaultName = ""
    @Published var error = ""
    private let queue = DispatchQueue(label: "com.audiosplitx.control")
    nonisolated private let worker = RoutingWorker()
    private var timer: Timer?
    private var busy = false
    private var shuttingDown = false
    private let store: URL
    init() {
        store = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AudioSplit X/routes.json")
        if FileManager.default.fileExists(atPath: store.path) {
            do { preferences = try JSONDecoder().decode([String: Preference].self, from: Data(contentsOf: store)) }
            catch { self.error = "Preferenze non leggibili: \(error.localizedDescription)" }
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }
    func update(_ row: Row, _ change: (inout Preference) -> Void) {
        var p = preferences[row.id] ?? Preference(name: row.name)
        change(&p); p.volume = max(0, min(1, p.volume)); preferences[row.id] = p
        do {
            try FileManager.default.createDirectory(at: store.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(preferences).write(to: store, options: .atomic)
        } catch { self.error = "Salvataggio fallito: \(error.localizedDescription)" }
        retry()
    }
    func retry() { queue.async { self.worker.retry() }; refresh() }
    func toggle() { enabled.toggle(); refresh() }
    func shutdown(_ finished: @escaping () -> Void) {
        shuttingDown = true; timer?.invalidate()
        queue.async { self.worker.stop(); DispatchQueue.main.async { finished() } }
    }
    func refresh() {
        guard !busy && !shuttingDown else { return }; busy = true
        let prefs = preferences, running = enabled
        queue.async {
            let result = self.worker.snapshot(preferences: prefs, enabled: running)
            let diagnostic = "AudioSplit X v0.1 · \(Date())\nDefault: \(result.2)\n" + result.0.map { "DEVICE \($0.name) | \($0.uid) | \($0.outputChannels)ch" }.joined(separator: "\n") + "\n" + result.1.map { "APP \($0.name) | \($0.id) | playing=\($0.playing) | active=\($0.active) | peak=\($0.peak) | \($0.status) | \($0.diagnostics)" }.joined(separator: "\n")
            let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs/AudioSplit X")
            try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
            try? diagnostic.write(to: logs.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                self.devices = result.0; self.rows = result.1; self.defaultName = result.2; self.busy = false
            }
        }
    }
}
