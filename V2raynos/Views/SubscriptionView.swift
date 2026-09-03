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

/// 订阅编辑：名称 + URL
struct SubscriptionEditView: View {
    let sub: Subscription
    var onSave: (Subscription) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("订阅信息") {
                    TextField("名称（分组名）", text: $name)
                    TextField("订阅 URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("编辑订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var s = sub
                        s.name = name.isEmpty ? sub.name : name
                        s.url = url.isEmpty ? sub.url : url
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
            }
        }
    }
}