import ServiceManagement

/// Wraps SMAppService (macOS 13+). Note: reliable registration requires a
/// signed, installed .app; unsigned dev builds may report `.notRegistered`
/// or throw — the caller surfaces the error.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
