import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var store: Store
    @State private var url = ""
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.subscriptions) { s in
                        VStack(alignment: .leading) {
                            Text(s.name).font(.headline)
                            Text(s.url).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            Text("更新于 \(s.lastUpdated, format: .dateTime)").font(.caption2).foregroundColor(.tertiary)
                        }
                    }
                    .onDelete { i in
                        store.subscriptions.remove(atOffsets: i)
                    }
                }
                Section("添加订阅") {
                    TextField("订阅 URL", text: $url).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("添加并更新") {
                        let s = Subscription(name: "订阅", url: url, groupID: store.currentGroupID())
                        store.addSubscription(s)
                        store.updateSubscriptions(from: url)
                        url = ""
                    }
                }
            }
            .navigationTitle("订阅")
        }
    }
}