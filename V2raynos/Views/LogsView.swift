import SwiftUI

struct LogsView: View {
    @State private var text = "（未运行）运行后在此显示 Xray 日志"
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text).font(.system(.caption, design: .monospaced)).padding()
            }
            .navigationTitle("运行日志")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("复制") {} }
            }
        }
    }
}