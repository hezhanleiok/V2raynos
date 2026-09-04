import SwiftUI
import UIKit
import Combine

/// Logcat：读取共享目录的 Xray 错误日志（xray_error.log，App 与扩展进程同一文件），1 秒自动刷新
struct LogsView: View {
    @State private var text = "（暂无日志）启动 VPN 后自动显示内核输出"
    @State private var lines: [String] = []
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

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
                    // 手动刷新
                    Button { loadLog() } label: { Image(systemName: "arrow.clockwise") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = lines.joined(separator: "\n")
                    } label: { Image(systemName: "doc.on.doc") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 清空日志
                    Button {
                        try? "".write(to: logURL, atomically: true, encoding: .utf8)
                        lines.removeAll()
                    } label: { Image(systemName: "trash") }
                }
            }
            .onAppear { loadLog() }
            .onReceive(timer) { _ in loadLog() }
        }
    }

    private func loadLog() {
        if let t = try? String(contentsOf: logURL, encoding: .utf8) {
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            lines = trimmed.isEmpty ? [] : trimmed.components(separatedBy: "\n").suffix(500)
            if lines.isEmpty { text = "（日志为空）内核启动后错误日志写入这里；正常连接时可能长时间无输出" }
        } else {
            text = "（暂无日志文件）首次启动 VPN 后生成 xray_error.log"
        }
    }
}