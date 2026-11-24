import SwiftUI

struct NotchView: View {
    @ObservedObject var controller: NotchController
    @ObservedObject var store: SnippetStore
    let geometry: NotchGeometry
    @State private var pendingDelete: Snippet?
    @FocusState private var searching: Bool

    private var size: CGSize { controller.isOpen ? NotchGeometry.expandedSize : geometry.collapsedSize }
    private var preview: Snippet? { store.items.first { $0.id == controller.previewID } }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(topRadius: controller.isOpen ? 12 : 6, bottomRadius: 18)
                .fill(controller.isOpen ? .black : .clear)
                .frame(width: size.width + 24, height: size.height)
                .shadow(color: .black.opacity(controller.isOpen ? 0.28 : 0), radius: 16, y: 8)
            VStack(spacing: 0) {
                HStack {
                    Text("NotchCopy").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Color.clear.frame(width: geometry.notchSize.width)
                    Spacer()
                    Text(controller.copiedID == nil ? "" : "已复制 ✓")
                        .font(.system(size: 10)).foregroundStyle(.green)
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 18)
                .frame(height: geometry.notchSize.height)
                VStack(spacing: 10) {
                    if let preview { previewPane(preview) } else { listPane }
                    HStack {
                        Text("\(store.items.count) 条文案")
                        Spacer()
                        Text(controller.copiedID == nil ? "↑↓ 选择   ↵ 复制   Esc 关闭" : "已复制，即将收起")
                    }.font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
                .frame(height: NotchGeometry.expandedSize.height - geometry.notchSize.height)
            }
            .frame(width: size.width, height: size.height, alignment: .top).clipped()
            .opacity(controller.isOpen ? 1 : 0)
            .accessibilityHidden(!controller.isOpen).allowsHitTesting(controller.isOpen)
        }
        .frame(width: size.width + 24, height: size.height, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .onReceive(NotificationCenter.default.publisher(for: .snippetStoreChanged)) { _ in store.reload() }
        .onChange(of: controller.searchFocusToken) { _, _ in searching = true }
        .onChange(of: controller.isOpen) { _, open in if !open { searching = false } }
        .onChange(of: store.query) { _, _ in controller.selectedID = store.filtered.first?.id }
        .alert("删除这条文案？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("删除", role: .destructive) {
                if let item = pendingDelete { store.remove(item) }
                pendingDelete = nil
            }
        } message: { Text("请确认不再需要这条文案。") }
    }

    private var listPane: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                    TextField("搜索文案", text: $store.query)
                        .font(.system(size: 13)).textFieldStyle(.plain)
                        .accessibilityIdentifier("snippet-search")
                        .focused($searching)
                    if !store.query.isEmpty {
                        Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }.padding(10).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                Button { controller.edit() } label: {
                    Image(systemName: "plus").font(.system(size: 15, weight: .medium)).frame(width: 30, height: 32)
                }.buttonStyle(.plain).help("新增文案 · ⌘N").accessibilityLabel("新增文案")
            }
            if store.fileBroken || store.saveError != nil {
                Text(store.saveError ?? "无法读取文案文件，原内容已保留。")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }
            if store.filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: store.items.isEmpty ? "text.quote" : "magnifyingglass")
                        .font(.system(size: 24, weight: .light)).foregroundStyle(.white.opacity(0.3))
                    Text(store.items.isEmpty ? "放一段常用文案在这里" : "没有找到相关文案")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    if store.items.isEmpty {
                        Button("新增文案") { controller.edit() }.buttonStyle(.plain).font(.system(size: 12))
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(store.filtered) { item in
                                SnippetRow(item: item, selected: controller.selectedID == item.id,
                                    copied: controller.copiedID == item.id,
                                    select: { controller.selectedID = item.id },
                                    copy: { controller.copy(item) },
                                    preview: { controller.preview(item) },
                                    edit: { controller.edit(item) },
                                    move: { store.move(item, to: 0) },
                                    remove: { pendingDelete = item })
                                    .id(item.id)
                            }
                        }
                    }
                    .onChange(of: controller.selectedID) { _, id in
                        if let id { withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewPane(_ item: Snippet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button { controller.previewID = nil } label: {
                    Image(systemName: "chevron.left").frame(width: 22, height: 24)
                }.buttonStyle(.plain).accessibilityLabel("返回文案列表")
                Text(item.label.isEmpty ? "文案预览" : item.label)
                    .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer()
                Text("\(item.text.count) 字").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            ScrollView {
                Text(item.text).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }.background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            Button { controller.copy(item) } label: {
                Text(controller.copiedID == item.id ? "已复制" : "复制全文")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(.white, in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SnippetRow: View {
    let item: Snippet
    let selected: Bool
    let copied: Bool
    let select: () -> Void
    let copy: () -> Void
    let preview: () -> Void
    let edit: () -> Void
    let move: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: copy) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.label.isEmpty ? "未命名文案" : item.label)
                        .font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Text(item.text.replacingOccurrences(of: "\n", with: "  "))
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.43)).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("复制：\(item.label.isEmpty ? "未命名文案" : item.label)")
            Image(systemName: "checkmark").font(.system(size: 11)).foregroundStyle(.green).opacity(copied ? 1 : 0)
            Button(action: preview) { Image(systemName: "eye").frame(width: 24, height: 26) }
                .buttonStyle(.plain).help("预览全文").accessibilityLabel("预览：\(item.label)")
                .opacity(selected ? 0.7 : 0.15)
            Menu {
                Button("编辑文案", action: edit)
                Button("移到最上面", action: move)
                Divider()
                Button("删除文案…", role: .destructive, action: remove)
            } label: { Image(systemName: "ellipsis").frame(width: 14, height: 24) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().opacity(selected ? 0.6 : 0.15)
            .accessibilityLabel("更多：\(item.label)")
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .background(.white.opacity(selected ? 0.075 : 0), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle()).onHover { if $0 { select() } }
    }
}
