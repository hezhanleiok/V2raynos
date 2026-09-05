import SwiftUI
import UIKit
import Combine

/// Logcat：读取共享目录的 Xray 错误日志（xray_error.log，App 与扩展进程同一文件）。
/// 计时器与页面生命周期绑定：onAppear 开启、onDisappear 立即释放，杜绝后台 CPU 与 I/O 占用。
struct LogsView: View {
    @State private var text = "（暂无日志）启动 VPN 后自动显示内核输出"
    @State private var lines: [String] = []
    @State private var timerSubscription: AnyCancellable? = nil

    private var logURL: URL { SharedGroup.dir.appendingPathComponent("xray_error.log") }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, ln in
                        Text(ln).font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if lines.isEmpty {
                        Text(text).font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary).padding()
                    }
                }
                .padding(8)
            }
            .navigationTitle("Logcat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { loadLog() } label: { Image(systemName: "arrow.clockwise") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = lines.joined(separator: "\n")
                    } label: { Image(systemName: "doc.on.doc") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        try? "".write(to: logURL, atomically: true, encoding: .utf8)
                        lines.removeAll()
                    } label: { Image(systemName: "trash") }
                }
            }
            .onAppear {
                loadLog()
                // 仅在页面处于前台显示时开启 1.5 秒轮询
                timerSubscription = Timer.publish(every: 1.5, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in loadLog() }
            }
            .onDisappear {
                // 离开页面立即取消定时器，杜绝后台 CPU 与 I/O 占用
                timerSubscription?.cancel()
                timerSubscription = nil
            }
        }
    }

    private func loadLog() {
        // 高频磁盘 IO 移到后台线程：主线程同步读文件会在日志变大后卡 UI / 触发 Watchdog
        DispatchQueue.global(qos: .background).async {
            if let t = try? String(contentsOf: self.logURL, encoding: .utf8) {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                let newLines = trimmed.isEmpty ? [] : trimmed.components(separatedBy: "\n").suffix(200)
                DispatchQueue.main.async {
                    self.lines = Array(newLines)
                    if self.lines.isEmpty { self.text = "（日志为空）内核启动后错误日志写入这里；正常连接时可能长时间无输出" }
                }
            } else {
                DispatchQueue.main.async {
                    self.text = "（暂无日志文件）首次启动 VPN 后生成 xray_error.log"
                }
            }
        }
    }
}