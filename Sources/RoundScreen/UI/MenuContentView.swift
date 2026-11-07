import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var model: RoundScreenModel

    var body: some View {
        Toggle(
            "启用屏幕圆角",
            isOn: Binding(
                get: { model.isEnabled },
                set: { model.setEnabled($0) }
            )
        )

        Divider()

        if model.isEnabled {
            if model.displayStatuses.isEmpty {
                Text("正在读取显示器…")
                    .disabled(true)
            } else {
                ForEach(model.displayStatuses) { status in
                    Text(status.menuDescription)
                        .disabled(true)
                }
            }
        } else {
            Text("已暂停")
                .disabled(true)
        }

        Divider()

        Button("设置…") {
            model.showSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("立即刷新") {
            model.refreshNow()
        }
        .disabled(!model.isEnabled)

        Divider()

        Button("退出 RoundScreen") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
