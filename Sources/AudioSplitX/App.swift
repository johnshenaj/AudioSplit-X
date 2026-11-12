import SwiftUI
import AppKit
import AudioCore

@main struct AudioSplitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    var panel: NSPopover!
    var window: NSWindow!
    var model: Model!
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--inventory") {
            for d in AudioDevices.outputs() { print("DEVICE \(d.id) | \(d.name) | \(d.uid) | \(d.outputChannels)ch") }
            for g in AudioProcesses.groups() { print("APP \(g.name) | \(g.key) | playing=\(g.isPlaying) | ids=\(g.processObjectIDs)") }
            exit(0)
        }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.audiosplitx.app").count <= 1 else { NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.accessory)
        model = Model()
        let view = MainView(model: model)
        panel = NSPopover(); panel.behavior = .transient
        panel.contentViewController = NSHostingController(rootView: view)
        panel.contentSize = NSSize(width: 480, height: 610)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "AudioSplit X")
        item.button?.toolTip = "AudioSplit X · uscite audio per app"
        item.button?.target = self; item.button?.action = #selector(togglePanel)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 610), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "AudioSplit X"; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view); window.center()
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func togglePanel() {
        if panel.isShown { panel.performClose(nil) }
        else if let button = item.button { panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY); NSApp.activate(ignoringOtherApps: true) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.shutdown { NSApp.reply(toApplicationShouldTerminate: true) }; return .terminateLater
    }
}
struct MainView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "arrow.triangle.branch").font(.title).foregroundStyle(.cyan)
                VStack(alignment: .leading) { Text("AudioSplit X").font(.title2.bold()); Text("Un’uscita per ogni app").foregroundStyle(.secondary) }
                Spacer()
                Text("0.1").foregroundStyle(.secondary)
            }
            HStack {
                Text("\(model.devices.count) uscite · Sistema: \(model.defaultName)").font(.caption)
                Spacer()
                Button("Riprova") { model.retry() }
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(model.rows) { row in AppRow(model: model, row: row) }
                    if model.rows.isEmpty { Text("Avvia una riproduzione in Chrome o ChatGPT per rilevare i processi audio.").padding() }
                }
            }
            if !model.error.isEmpty { Text(model.error).font(.caption).foregroundStyle(.orange) }
            Text("“Segnale ricevuto” conferma la cattura. L’ascolto sull’uscita scelta va verificato. Il volume agisce sull’audio instradato.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(model.enabled ? "Sospendi tutto" : "Riprendi") { model.toggle() }
                Button("Permessi audio") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!) }
                Spacer()
                Button("Esci") { NSApp.terminate(nil) }
            }.controlSize(.small)
        }.padding(18).frame(width: 480, height: 610).background(Color(nsColor: .windowBackgroundColor))
    }
}
struct AppRow: View {
    @ObservedObject var model: Model
    let row: Row
    var preference: Preference { model.preferences[row.id] ?? Preference(name: row.name) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = NSRunningApplication(processIdentifier: row.pid)?.icon { Image(nsImage: icon).resizable().frame(width: 27, height: 27) }
                Text(row.name).font(.headline)
                Spacer()
                Circle().fill(row.playing ? Color.green : Color.gray).frame(width: 6, height: 6)
                Text(row.playing ? "Audio attivo" : "Inattiva").font(.caption).foregroundStyle(.secondary)
            }
            Picker("Uscita", selection: Binding(get: { preference.output }, set: { uid in model.update(row) { $0.output = uid } })) {
                Text("Gestita dall’app / sistema").tag("")
                ForEach(model.devices) { Text($0.name).tag($0.uid) }
                if !preference.output.isEmpty && !model.devices.contains(where: { $0.uid == preference.output }) {
                    Text("Uscita salvata (scollegata)").tag(preference.output)
                }
            }.labelsHidden()
            HStack {
                Button { model.update(row) { $0.muted.toggle() } } label: { Image(systemName: preference.muted ? "speaker.slash.fill" : "speaker.wave.2.fill") }.help("Mute per questa app")
                Slider(value: Binding(get: { Double(preference.volume) }, set: { v in model.update(row) { $0.volume = Float(v) } }), in: 0...1)
                Text("\(Int(preference.volume * 100))%").monospacedDigit().frame(width: 38)
                Button("Reset") { model.update(row) { $0 = Preference(name: row.name) } }.font(.caption)
            }
            HStack(spacing: 6) {
                ProgressView(value: Double(min(row.peak, 1))).frame(width: 45)
                Text(row.status).font(.caption2).foregroundStyle(row.active ? Color.cyan : Color.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
    }
}
