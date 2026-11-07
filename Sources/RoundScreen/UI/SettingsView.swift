import ApplicationServices
import AppKit
import Combine
import RoundScreenCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: RoundScreenModel
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var cursorGuardActive = false

    private var normalRadius: Binding<Double> {
        Binding(
            get: { model.settings.normalRadius },
            set: { model.setNormalRadius($0) }
        )
    }

    private var maximizedRadius: Binding<Double> {
        Binding(
            get: { model.settings.maximizedRadius },
            set: { model.setMaximizedRadius($0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(
                    isOn: Binding(
                        get: { model.isEnabled },
                        set: { model.setEnabled($0) }
                    )
                ) {
                    Label("启用屏幕圆角", systemImage: "rectangle.inset.filled")
                }
            } footer: {
                Text("关闭后立即移除所有显示器上的遮罩。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("圆角") {
                radiusRow(
                    title: "正常状态",
                    value: normalRadius,
                    tint: .blue,
                    detail: "贴近硬件圆角"
                )
                radiusRow(
                    title: "最大化",
                    value: maximizedRadius,
                    tint: .orange,
                    detail: "贴近 App 窗口圆角"
                )

                HStack {
                    Label(
                        "原生全屏",
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
                    Spacer()
                    Text("0 pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Button("恢复默认 20 / 14") {
                    model.resetRadii()
                }
            }

            Section("显示器 · 每屏 / 每角独立") {
                if model.displayStatuses.isEmpty {
                    Text(model.isEnabled ? "正在读取显示器…" : "已暂停")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.displayStatuses) { status in
                        HStack(spacing: 12) {
                            Image(systemName: status.symbolName)
                                .foregroundStyle(status.color)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.name)
                                Text(status.stateLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(status.radiusLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("鼠标排斥") {
                HStack {
                    Label("辅助功能权限", systemImage: "cursorarrow.motionlines")
                    Spacer()
                    Text(accessibilityTrusted ? "已授权" : "未授权")
                        .foregroundStyle(
                            accessibilityTrusted ? Color.green : Color.orange
                        )
                    Button(accessibilityTrusted ? "打开系统设置" : "去授权") {
                        openAccessibilitySettings()
                    }
                }

                HStack {
                    Text("鼠标限制")
                    Spacer()
                    Text(
                        !model.isEnabled ? "已暂停"
                            : cursorGuardActive ? "拦截器已运行" : "未启动"
                    )
                    .foregroundStyle(
                        cursorGuardActive ? Color.green : Color.orange
                    )
                }

                Text(
                    "鼠标限制需要辅助功能授权，并且拦截器实际运行。圆角遮罩始终保留，点击仍会穿透到下方窗口。"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    "触发角：鼠标碰到圆角缺口并连续停留约 0.7 秒后，执行系统设置中该角的动作；快速划过不会触发。不要求实际光标到达屏幕物理角。"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    "如果已授权但鼠标限制仍未启动，请在系统设置中重新授权当前版本的 RoundScreen。应用会自动重试。"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("判定规则") {
                LabeledContent("作用范围", value: "A · 每块显示器独立")
                LabeledContent("正常", value: "无窗口贴住对应角")
                LabeledContent("最大化", value: "当前显示器任一窗口贴合工作区")
                LabeledContent("单角", value: "窗口贴住该角 → 该角 14 pt")
                LabeledContent("全屏", value: "最前面的窗口覆盖整屏 → 隐藏")
            }

            Section {
                Text(
                    "状态检测使用公开窗口元数据，无需屏幕录制权限。圆角使用连续曲率路径，由固定全屏图层绘制，不会进入截图；鼠标排斥需要辅助功能权限。"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(minWidth: 560, minHeight: 560)
        .onAppear {
            refreshAccessibilityStatus()
        }
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { _ in
            refreshAccessibilityStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            refreshAccessibilityStatus()
        }
    }

    private func refreshAccessibilityStatus() {
        accessibilityTrusted = AXIsProcessTrusted()
        cursorGuardActive = model.isCursorGuardActive
    }

    private func openAccessibilitySettings() {
        _ = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        )
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    private func radiusRow(
        title: String,
        value: Binding<Double>,
        tint: Color,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(title)
                    .frame(width: 92, alignment: .leading)

                Slider(value: value, in: 0 ... 60, step: 1)
                    .tint(tint)

                Text("\(Int(value.wrappedValue.rounded())) pt")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 104)
        }
    }
}

private extension DisplayStatus {
    var color: Color {
        if corners.isFullscreen {
            return .green
        }
        if !corners.isUniform {
            return .purple
        }
        switch corners.topLeft {
        case .normal:
            return .blue
        case .maximized:
            return .orange
        case .fullscreen:
            return .green
        }
    }
}
