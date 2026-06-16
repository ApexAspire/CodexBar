import AppKit
import SwiftUI

struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 20, height: 20)
            .onReceive(NotificationCenter.default.publisher(for: .codexbarOpenSettings)) { _ in
                Task { @MainActor in
                    // LSUIElement apps can't front the Settings window in .accessory; switch to .regular
                    // and activate, then open via the SwiftUI openSettings() environment action — the
                    // same path the app menu's "Settings…" uses (which works). The showSettingsWindow:
                    // selector reports handled=true but never creates the window, so it must not be used.
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    self.openSettings()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
                // When the Settings window closes, return to menu-bar-only (.accessory) so the app stops
                // showing in the Dock — unless another real window is still open.
                guard let closing = note.object as? NSWindow else { return }
                DispatchQueue.main.async {
                    let hasUserWindow = NSApp.windows.contains { window in
                        window !== closing && window.isVisible && window.canBecomeKey
                            && window.title != "CodexBarLifecycleKeepalive"
                            && !window.title.hasPrefix("codexbar-")
                    }
                    if !hasUserWindow {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
            }
            .task {
                // Migrate keychain items to reduce permission prompts during development (runs off main thread)
                await Task.detached(priority: .userInitiated) {
                    KeychainMigration.migrateIfNeeded()
                }.value
            }
            .onAppear {
                if let window = NSApp.windows.first(where: { $0.title == "CodexBarLifecycleKeepalive" }) {
                    // Make the keepalive window truly invisible and non-interactive.
                    window.styleMask = [.borderless]
                    window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
                    window.isExcludedFromWindowsMenu = true
                    window.level = .floating
                    window.isOpaque = false
                    window.alphaValue = 0
                    window.backgroundColor = .clear
                    window.hasShadow = false
                    window.ignoresMouseEvents = true
                    window.canHide = false
                    window.setContentSize(NSSize(width: 1, height: 1))
                    window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
                }
            }
    }
}
