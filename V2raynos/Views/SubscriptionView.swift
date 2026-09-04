import SwiftUI
import UIKit

/// 订阅分组管理：支持编辑（名称/URL）、更新、删除
struct SubscriptionView: View {
    @EnvironmentObject var store: Store
    @State private var url = ""
    @State private var name = ""
    @State private var showQR = false
    @State private var updatingID: String? = nil
    @State private var editingSub: Subscription? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("已添加订阅（自动创建分组）") {
                    ForEach(store.subscriptions) { s in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(s.name).font(.headline)
                                Spacer()
                                if updatingID == s.id { ProgressView().scaleEffect(0.8) }
                                Button("更新") {
                                    updatingID = s.id
                                    store.updateSubscriptions(from: s.url)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { updatingID = nil }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            Text(s.url).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            Text("更新于 \(s.lastUpdated, format: .dateTime)").font(.caption2).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingSub = s }
                        .contextMenu {
                            Button { editingSub = s } label: { Label("编辑", systemImage: "square.and.pencil") }
                            Button {
                                updatingID = s.id
                                store.updateSubscriptions(from: s.url)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { updatingID = nil }
                            } label: { Label("更新订阅", systemImage: "arrow.triangle.2.circlepath") }
                            Button(role: .destructive) { store.removeSubscription(s) } label: { Label("删除", systemImage: "trash") }
                        }
                    }
                    .onDelete { i in
                        let subs = store.subscriptions
                        for idx in i { store.removeSubscription(subs[idx]) }
                    }
                    if let err = store.lastSubscriptionError {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                }
                Section("添加订阅") {
                    TextField("名称（可选，将作为分组名）", text: $name)
                    TextField("订阅 URL", text: $url).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("添加并更新") {
                        let subName = name.isEmpty ? "订阅 \(store.subscriptions.count + 1)" : name
                        let s = Subscription(name: subName, url: url, groupID: "")
                        store.addSubscription(s)   // 自动建同名分组
                        store.updateSubscriptions(from: url)
                        url = ""; name = ""
                    }
                    Button { showQR = true } label: { Label("扫码添加订阅", systemImage: "qrcode.viewfinder") }
                }
            }
            .navigationTitle("订阅分组")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { store.lastSubscriptionError = nil }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("全部更新") { store.updateAllSubscriptions() }
                }
            }
            .sheet(isPresented: $showQR) {
                QRScannerView { code in
                    guard code.hasPrefix("http") else { return }
                    let subName = "订阅-扫码"
                    let s = Subscription(name: subName, url: code, groupID: "")
                    store.addSubscription(s)
                    store.updateSubscriptions(from: code)
                }
            }
            .sheet(item: $editingSub) { sub in
                SubscriptionEditView(sub: sub) { updated in
                    store.updateSubscription(updated)
                    editingSub = nil
                }
            }
        }
    }
}

/// 订阅编辑：1:1 v2rayNG 订阅设置模板（含链式代理）
struct SubscriptionEditView: View {
    let sub: Subscription
    var onSave: (Subscription) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: Store
    @State private var name = ""
    @State private var url = ""
    @State private var userAgent = ""
    @State private var requestHeaders = ""
    @State private var filter = ""
    @State private var enabled = true
    @State private var autoUpdate = false
    @State private var updateIntervalMinutes = 1440
    @State private var prevProfile = ""
    @State private var nextProfile = ""

    /// 可作前置/落地代理的节点别名（全部分组的节点）
    private var profileNames: [String] { store.servers.map { $0.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("备注", text: $name)
                    TextField("URL（可选）", text: $url, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("User Agent", text: $userAgent)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("高级设置") {
                    TextField("请求头（JSON 格式）", text: $requestHeaders, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("别名正则过滤", text: $filter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("更新设置") {
                    Toggle("启用更新", isOn: $enabled)
                    Toggle("启用自动更新", isOn: $autoUpdate)
                    if autoUpdate {
                        Stepper("自动更新间隔：\(updateIntervalMinutes) 分钟", value: $updateIntervalMinutes, in: 15...10080, step: 15)
                    }
                }
                Section("链式代理") {
                    Picker("前置代理配置别名", selection: $prevProfile) {
                        Text("（无）").tag("")
                        ForEach(Array(profileNames.enumerated()), id: \.offset) { _, n in
                            Text(n).tag(n)
                        }
                    }
                    Text("所选代理会添加到该订阅中每个配置的前面，作为该配置代理链的入口节点。")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("落地代理配置别名", selection: $nextProfile) {
                        Text("（无）").tag("")
                        ForEach(Array(profileNames.enumerated()), id: \.offset) { _, n in
                            Text(n).tag(n)
                        }
                    }
                    Text("所选代理会添加到该订阅中每个配置的后面，作为该配置代理链的出口节点。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("编辑订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        var s = sub
                        s.name = name
                        s.url = url
                        s.userAgent = userAgent.isEmpty ? nil : userAgent
                        s.requestHeaders = requestHeaders.isEmpty ? nil : requestHeaders
                        s.filter = filter.isEmpty ? nil : filter
                        s.enabled = enabled
                        s.autoUpdate = autoUpdate
                        s.updateIntervalSeconds = autoUpdate ? updateIntervalMinutes * 60 : 0
                        s.prevProfile = prevProfile.isEmpty ? nil : prevProfile
                        s.nextProfile = nextProfile.isEmpty ? nil : nextProfile
                        onSave(s)
                        dismiss()
                    }
                    .disabled(url.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                name = sub.name
                url = sub.url
                userAgent = sub.userAgent ?? ""
                requestHeaders = sub.requestHeaders ?? ""
                filter = sub.filter ?? ""
                enabled = sub.enabled
                autoUpdate = sub.autoUpdate
                updateIntervalMinutes = max(15, sub.updateIntervalSeconds / 60)
                prevProfile = sub.prevProfile ?? ""
                nextProfile = sub.nextProfile ?? ""
            }
        }
    }
}