import AppKit

@main
@MainActor
struct MonoTabApp {
    private static var strongAppDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        self.strongAppDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}
