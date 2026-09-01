import SwiftUI

struct RoutingView: View {
    @State private var prefab: RoutingPrefab = .bypassLAN
    @State private var rules: [RoutingRule] = []
    var body: some View {
        NavigationStack {
            Form {
                Picker("路由模式", selection: $prefab) {
                    ForEach(RoutingPrefab.allCases) { Text($0.display).tag($0) }
                }
                Section("规则") {
                    ForEach($rules) { $r in
                        Toggle(isOn: $r.enabled) {
                            VStack(alignment: .leading) {
                                Text(r.domain).font(.subheadline)
                                Text("走 \(r.outbound)").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { rules.remove(atOffsets: $0) }
                    Button("添加规则") { rules.append(RoutingRule(domain: "google.com", outbound: "proxy")) }
                }
            }
            .navigationTitle("路由")
        }
    }
}