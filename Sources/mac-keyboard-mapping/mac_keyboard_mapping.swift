import AppKit
import ApplicationServices
import Foundation

@MainActor
final class RightCmdAgentAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var runtimeStatusItem: NSMenuItem?
    private var startupAtLoginItem: NSMenuItem?
    private var accessibilityPermissionItem: NSMenuItem?
    private var inputMonitoringPermissionItem: NSMenuItem?

    private var service: RightCmdService?
    private let launchAgentManager = LaunchAgentManager()
    private var lastStartupFailed = false

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        refreshPermissionItems()
        refreshStartupAtLoginState()
        startServiceIfReady()
        refreshRuntimeStatus()
    }

    func applicationWillTerminate(_: Notification) {
        service?.stop()
    }

    func menuWillOpen(_: NSMenu) {
        refreshPermissionItems()
        refreshStartupAtLoginState()
        startServiceIfReady()
        refreshRuntimeStatus()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.toolTip = "RightCmdAgent"
            button.title = "RC"
        }

        let menu = NSMenu()
        menu.delegate = self

        let runtime = NSMenuItem(title: "状态: 启动中", action: nil, keyEquivalent: "")
        runtime.isEnabled = false
        runtimeStatusItem = runtime
        menu.addItem(runtime)

        let accessibility = NSMenuItem(
            title: "辅助功能权限: 检查中",
            action: #selector(requestAccessibilityPermission),
            keyEquivalent: ""
        )
        accessibility.target = self
        accessibilityPermissionItem = accessibility
        menu.addItem(accessibility)

        let inputMonitoring = NSMenuItem(
            title: "输入监控权限: 检查中",
            action: #selector(requestInputMonitoringPermission),
            keyEquivalent: ""
        )
        inputMonitoring.target = self
        inputMonitoringPermissionItem = inputMonitoring
        menu.addItem(inputMonitoring)

        let refreshPermissions = NSMenuItem(
            title: "刷新权限状态",
            action: #selector(refreshPermissionsStatus),
            keyEquivalent: "r"
        )
        refreshPermissions.target = self
        menu.addItem(refreshPermissions)
        let startupToggle = NSMenuItem(title: "开机启动", action: #selector(toggleStartupAtLogin), keyEquivalent: "")
        startupToggle.target = self
        startupAtLoginItem = startupToggle
        menu.addItem(startupToggle)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "退出 RightCmdAgent", action: #selector(terminateFromMenu), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
    }

    private func startService() {
        guard service == nil else {
            return
        }

        let config = AppConfig.load()

        do {
            let service = try RightCmdService(config: config)
            try service.start()
            self.service = service
            lastStartupFailed = false
        } catch {
            lastStartupFailed = true
            fputs("[rightcmd-agent] Failed to start service: \(error)\n", stderr)
        }
    }

    private func refreshRuntimeStatus() {
        if let service {
            if isAccessibilityGranted() && isInputMonitoringGranted() {
                setRuntimeStatus("状态: 运行中（\(service.modeText)）")
            } else {
                setRuntimeStatus("状态: 运行中，但权限不完整")
            }
            return
        }

        if lastStartupFailed {
            setRuntimeStatus("状态: 未运行，点击权限项后重试")
            return
        }

        if isAccessibilityGranted() && isInputMonitoringGranted() {
            setRuntimeStatus("状态: 权限就绪，服务未运行")
        } else {
            setRuntimeStatus("状态: 缺少权限")
        }
    }

    private func setRuntimeStatus(_ text: String) {
        runtimeStatusItem?.title = text
    }

    private func refreshPermissionItems() {
        let accessibilityGranted = isAccessibilityGranted()
        let inputMonitoringGranted = isInputMonitoringGranted()

        accessibilityPermissionItem?.title = accessibilityGranted
            ? "辅助功能权限: 已授权"
            : "辅助功能权限: 未授权（点击申请）"

        inputMonitoringPermissionItem?.title = inputMonitoringGranted
            ? "输入监控权限: 已授权"
            : "输入监控权限: 未授权（点击申请）"

        accessibilityPermissionItem?.state = accessibilityGranted ? .on : .off
        inputMonitoringPermissionItem?.state = inputMonitoringGranted ? .on : .off
    }

    private func refreshStartupAtLoginState() {
        startupAtLoginItem?.state = launchAgentManager.isEnabled() ? .on : .off
    }

    private func isAccessibilityGranted(prompt: Bool = false) -> Bool {
        if prompt {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        return AXIsProcessTrusted()
    }

    private func isInputMonitoringGranted(prompt: Bool = false) -> Bool {
        if #available(macOS 10.15, *) {
            return prompt ? CGRequestListenEventAccess() : CGPreflightListenEventAccess()
        }

        return true
    }

    @objc private func requestAccessibilityPermission() {
        let granted = isAccessibilityGranted(prompt: true)
        if !granted {
            openPrivacySettings(anchor: "Privacy_Accessibility")
        }

        refreshPermissionItems()
        startServiceIfReady()
        refreshRuntimeStatus()
    }

    @objc private func requestInputMonitoringPermission() {
        let granted = isInputMonitoringGranted(prompt: true)
        if !granted {
            openPrivacySettings(anchor: "Privacy_ListenEvent")
        }

        refreshPermissionItems()
        startServiceIfReady()
        refreshRuntimeStatus()
    }

    @objc private func refreshPermissionsStatus() {
        refreshPermissionItems()
        startServiceIfReady()
        refreshRuntimeStatus()
    }
    private func startServiceIfReady() {
        guard service == nil else {
            return
        }

        guard isAccessibilityGranted(), isInputMonitoringGranted() else {
            return
        }

        startService()
    }

    private func openPrivacySettings(anchor: String) {
        if let anchoredURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(anchoredURL)
            return
        }

        if let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(fallbackURL)
        }
    }

    @objc private func toggleStartupAtLogin() {
        let shouldEnable = !launchAgentManager.isEnabled()
        guard let executablePath = Bundle.main.executablePath else {
            setRuntimeStatus("状态: 无法解析可执行文件路径")
            return
        }

        do {
            try launchAgentManager.setEnabled(
                shouldEnable,
                executablePath: executablePath,
                configPath: AppConfig.resolvedPath()
            )
            refreshStartupAtLoginState()
        } catch {
            setRuntimeStatus("状态: 开机启动设置失败")
            fputs("[rightcmd-agent] Failed to toggle startup at login: \(error)\n", stderr)
        }
    }

    @objc private func terminateFromMenu() {
        NSApp.terminate(nil)
    }
}

@main
@MainActor
struct RightCmdAgentMain {
    private static let delegate = RightCmdAgentAppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}