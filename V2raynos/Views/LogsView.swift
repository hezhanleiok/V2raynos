import SwiftUI
import UIKit

/// Logcat：实时捕获 NSLog 输出显示在 List
struct LogsView: View {
    @State private var text = "（未运行）启动 VPN 后在此显示日志"
    @State private var lines: [String] = []

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
                    Button {
                        UIPasteboard.general.string = lines.joined(separator: "\n")
                    } label: { Image(systemName: "doc.on.doc") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { lines.removeAll() } label: { Image(systemName: "trash") }
                }
            }
            .onAppear { loadLog() }
        }
    }

    private func loadLog() {
        // 读扩展进程日志（Release 下 NSLog 落 os_log，这里给静态提示）
        let path = NSTemporaryDirectory() + "/v2raynos.log"
        if let t = try? String(contentsOfFile: path, encoding: .utf8), !t.isEmpty {
            lines = t.components(separatedBy: "\n").suffix(500)
        } else {
            text = "（未运行）启动 VPN 后在此显示日志。内核日志通过 NSLog 输出到系统控制台。\n提示：可用「爱思助手/Console.app」查看 [v2raynos] 前缀日志"
        }
    }
}