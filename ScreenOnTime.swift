import Cocoa
import IOKit.ps
import ServiceManagement
import SwiftUI

// MARK: - View model

final class Model: ObservableObject {
    @Published var timeText = "0m"
    @Published var unplugPct: Int?
    @Published var currentPct: Int?
    @Published var since = "?"
    @Published var loginEnabled = false
}

// MARK: - Popover UI

struct Frosted: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .vibrantDark)
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

let accent = Color(red: 0.19, green: 0.84, blue: 0.40)

struct Row: View {
    let icon: String, label: String, value: String
    var tint: Color = .white
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 18).foregroundColor(tint.opacity(0.9))
            Text(label).foregroundColor(.white.opacity(0.65))
            Spacer()
            Text(value).fontWeight(.semibold).foregroundColor(tint)
        }
        .font(.system(size: 13, design: .rounded))
        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
    }
}

struct PopoverView: View {
    @ObservedObject var m: Model
    var toggleLogin: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 7, height: 7)
                    .shadow(color: accent.opacity(0.9), radius: 4)
                Text("ON BATTERY").font(.system(size: 10, weight: .bold)).tracking(1.4)
                    .foregroundColor(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(m.timeText)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
                Text("screen on time")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
            VStack(spacing: 10) {
                if let p = m.unplugPct {
                    Row(icon: "battery.100.bolt", label: "Unplugged at", value: "\(p)%", tint: accent)
                }
                Row(icon: "clock", label: "Unplugged since", value: m.since)
                if let c = m.currentPct {
                    Row(icon: "battery.50", label: "Battery now", value: "\(c)%")
                    if let p = m.unplugPct, p >= c {
                        Row(icon: "arrow.down.right", label: "Used", value: "\(p - c)%")
                    }
                }
            }
            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
            Toggle(isOn: Binding(get: { m.loginEnabled }, set: { _ in toggleLogin() })) {
                Text("Launch at Login")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
            }
            .toggleStyle(.switch).tint(accent)
            Button(action: quit) {
                Text("Quit").font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(width: 270)
        .background(ZStack { Frosted(); Color.black.opacity(0.72) })
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1))
    }
}

// MARK: - Panel

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - App

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var panel: Panel?
    var clickMonitor: Any?
    let model = Model()
    var onBattery = false
    var accumulated: TimeInterval = 0
    var screenOnSince: Date?
    var unplugAt: Date?

    func applicationDidFinishLaunching(_ n: Notification) {
        item.button?.target = self
        item.button?.action = #selector(togglePopover)

        let host = NSHostingView(rootView: PopoverView(m: model,
                                  toggleLogin: { [weak self] in self?.toggleLogin() },
                                  quit: { NSApp.terminate(nil) }))
        host.setFrameSize(host.fittingSize)
        let pnl = Panel(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        pnl.contentView = host
        pnl.isOpaque = false
        pnl.backgroundColor = .clear
        pnl.hasShadow = true
        pnl.level = .popUpMenu
        pnl.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel = pnl

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(screenSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(screenSleep), name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(screenWake), name: NSWorkspace.screensDidWakeNotification, object: nil)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let src = IOPSNotificationCreateRunLoopSource({ c in
            Unmanaged<App>.fromOpaque(c!).takeUnretainedValue().powerChanged()
        }, ctx).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)

        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refresh() }
        powerChanged()
    }

    @objc func togglePopover() {
        guard let pnl = panel else { return }
        if pnl.isVisible { closePanel(); return }
        refresh()
        guard let bw = item.button?.window else { return }
        let screen = bw.screen ?? NSScreen.main!
        let host = pnl.contentView as! NSHostingView<PopoverView>
        let size = host.fittingSize
        var x = bw.frame.midX - size.width / 2
        x = min(max(x, screen.frame.minX + 8), screen.frame.maxX - size.width - 8)
        let y = screen.visibleFrame.maxY - size.height - 6
        pnl.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        pnl.makeKeyAndOrderFront(nil)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    func closePanel() {
        panel?.orderOut(nil)
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    func toggleLogin() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled { try svc.unregister() } else { try svc.register() }
        } catch { NSLog("Launch at login failed: \(error)") }
        model.loginEnabled = svc.status == .enabled
    }

    func isOnBattery() -> Bool {
        let snap = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let t = IOPSGetProvidingPowerSourceType(snap).takeUnretainedValue() as String
        return t == "Battery Power"
    }

    func batteryPercent() -> Int? {
        let snap = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(snap).takeRetainedValue() as [CFTypeRef]
        for ps in list {
            if let d = IOPSGetPowerSourceDescription(snap, ps)?.takeUnretainedValue() as? [String: Any],
               let cur = d[kIOPSCurrentCapacityKey] as? Int { return cur }
        }
        return nil
    }

    func powerChanged() {
        let b = isOnBattery()
        if b && !onBattery {
            accumulated = 0
            unplugAt = Date()
            model.unplugPct = batteryPercent()
            screenOnSince = CGDisplayIsAsleep(CGMainDisplayID()) == 0 ? Date() : nil
        }
        if !b { screenOnSince = nil; unplugAt = nil; model.unplugPct = nil }
        onBattery = b
        refresh()
    }

    @objc func screenSleep() {
        if let s = screenOnSince { accumulated += Date().timeIntervalSince(s); screenOnSince = nil }
        refresh()
    }

    @objc func screenWake() {
        if onBattery && screenOnSince == nil { screenOnSince = Date() }
        refresh()
    }

    func fmt(_ t: TimeInterval) -> String {
        let m = Int(t / 60)
        return m >= 60 ? "\(m / 60)h \(String(format: "%02d", m % 60))m" : "\(m)m"
    }

    func refresh() {
        item.isVisible = onBattery
        guard onBattery else { closePanel(); return }
        let total = accumulated + (screenOnSince.map { Date().timeIntervalSince($0) } ?? 0)
        item.button?.title = "☀︎ " + fmt(total).replacingOccurrences(of: " ", with: "")
        model.timeText = fmt(total)
        model.currentPct = batteryPercent()
        model.since = unplugAt.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? "?"
        model.loginEnabled = SMAppService.mainApp.status == .enabled
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
