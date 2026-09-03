import SwiftUI

/// 路由设置：域名策略 + 规则列表（1:1 v2rayNG）
struct RoutingView: View {
    @EnvironmentObject var store: Store
    @State private var domainStrategy = "IPIfNonMatch"
    @State private var rules: [RoutingRule] = [
        RoutingRule(domain: "geosite:google", outbound: "proxy"),
        RoutingRule(domain: "geosite:cn", outbound: "direct"),
    ]
    @State private var editingRule: RoutingRule? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("域名策略") {
                    Picker("域名策略", selection: $domainStrategy) {
                        Text("AsIs").tag("AsIs")
                        Text("IPIfNonMatch").tag("IPIfNonMatch")
                        Text("IPOnDemand").tag("IPOnDemand")
                    }
                }
                Section("规则列表") {
                    ForEach($rules) { $r in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ruleName(r))
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("[\(r.domain)]")
                                    .font(.caption).foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(r.outbound)
                                .font(.caption.weight(.bold))
                                .foregroundColor(outboundColor(r.outbound))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(outboundColor(r.outbound).opacity(0.15)))
                            Button { editingRule = r } label: {
                                Image(systemName: "square.and.pencil")
                            }
                            .buttonStyle(.plain)
                            Toggle("", isOn: $r.enabled).labelsHidden().frame(width: 44)
                        }
                    }
                    .onDelete { rules.remove(atOffsets: $0) }
                    Button {
                        rules.append(RoutingRule(domain: "google.com", outbound: "proxy"))
                    } label: {
                        Label("添加规则", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("路由设置")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingRule) { rule in
                RuleEditorView(rule: rule) { updated in
                    if let i = rules.firstIndex(where: { $0.id == updated.id }) { rules[i] = updated }
                    editingRule = nil
                }
            }
        }
    }

    func ruleName(_ r: RoutingRule) -> String {
        let d = r.domain
        if d.hasPrefix("geosite:") { return "代理 \(d.replacingOccurrences(of: "geosite:", with: ""))" }
        if r.outbound == "block" { return "屏蔽域名" }
        if r.outbound == "direct" { return "直连 \(d)" }
        return "代理 \(d)"
    }

    func outboundColor(_ out: String) -> Color {
        if out == "proxy" { return .orange }
        if out == "block" { return .red }
        return .green
    }
}

/// 规则编辑器
struct RuleEditorView: View {
    let rule: RoutingRule
    var onSave: (RoutingRule) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var domain = ""
    @State private var outbound = "proxy"

    var body: some View {
        NavigationStack {
            Form {
                Section("目标") {
                    TextField("域名 / geosite:xxx / geoip:xxx", text: $domain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("出站策略") {
                    Picker("出站", selection: $outbound) {
                        Text("proxy (代理)").tag("proxy")
                        Text("direct (直连)").tag("direct")
                        Text("block (屏蔽)").tag("block")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("编辑规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var r = rule
                        r.domain = domain.isEmpty ? rule.domain : domain
                        r.outbound = outbound
                        onSave(r)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                domain = rule.domain; outbound = rule.outbound
            }
        }
    }
}