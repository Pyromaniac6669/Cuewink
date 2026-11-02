import ServiceManagement

enum LoginItemStatus {
    case disabled, enabled, requiresApproval, unconfirmed
}

protocol LoginItemManaging {
    var status: LoginItemStatus { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}

struct SystemLoginItem: LoginItemManaging {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .disabled
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unconfirmed
        @unknown default: return .unconfirmed
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if status == .enabled || status == .requiresApproval { return }
            try SMAppService.mainApp.register()
        } else if status != .disabled {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
