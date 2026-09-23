import SwiftUI
import CloudKit
import UIKit

@MainActor final class FamilyInvitationInbox: ObservableObject {
    struct Invitation: Identifiable {
        let metadata: CKShare.Metadata
        var id: String { metadata.share.recordID.recordName }
    }
    static let shared = FamilyInvitationInbox()
    @Published var invitation: Invitation?
    func receive(_ metadata: CKShare.Metadata) { invitation = Invitation(metadata: metadata) }
}

/// Both cold launches and invitations opened while running enter the same inbox.
final class FamilySceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata { FamilyInvitationInbox.shared.receive(metadata) }
    }
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        FamilyInvitationInbox.shared.receive(metadata)
    }
}
final class FamilyAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = FamilySceneDelegate.self
        return configuration
    }
}

struct FamilySharingView: View {
    @ObservedObject var cloud: FamilyCloudController
    @State private var confirmCreate = false
    @State private var confirmDisconnect = false
    @State private var familyToJoin: FamilyCloudController.RemoteFamily?
    @State private var showJoinConfirmation = false
    @State private var keepDeviceVersion = false

    /// Four steps, in the order they fail. The first two are questions about this
    /// iPhone that can be answered before anything is uploaded, so a family finds out
    /// that iCloud is switched off here rather than after tapping Create.
    @ViewBuilder private var setup: some View {
        Section("Set up family sharing · 设置家庭共享") {
            step(1, "iCloud account", "iCloud 账号", cloud.accountCheck)
            if case .blocked = cloud.accountCheck {
                Button("Open iPhone Settings · 打开系统设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }.font(.footnote)
            }
            step(2, "CloudKit container", "CloudKit 容器", cloud.containerCheck)
            Button("Check again · 重新检查") { Task { await cloud.runSetupChecks() } }
                .font(.footnote).disabled(cloud.isBusy)
        }
        Section("3 · Before you start · 开始之前") {
            Text("Your kitchen is copied to your own private iCloud storage. Only people you invite can open it, and only from their own iPhone. 厨房数据会复制到你的私人 iCloud，仅受邀成员可在自己的 iPhone 上访问。")
            Text("Menus, shopping, stock, recipes, family settings and meal history travel. Photos, voice and this phone's display settings stay here. 菜单、采购、库存、菜谱、家庭资料与用餐记录会同步；照片、语音与本机显示设置不会。")
            Text("Your current kitchen is kept as it is. Returning to it later restores exactly this. 当前的本机厨房会原样保留，之后可随时恢复。")
        }.font(.footnote).foregroundStyle(.secondary)
        Section("4 · Create or join · 创建或加入") {
            Button("Create family from this kitchen · 用当前厨房创建家庭") { confirmCreate = true }
                .disabled(cloud.isBusy || cloud.loadError != nil || !cloud.setupReady)
            Button("Find my families · 查找我的家庭") { Task { await cloud.findFamilies() } }
                .disabled(cloud.isBusy || cloud.loadError != nil || !cloud.setupReady)
            Text("Already invited? Open the invitation link on this iPhone and confirm — there is nothing to do here first. 已收到邀请：在本机打开链接并确认即可，无需先在此设置。")
                .font(.footnote).foregroundStyle(.secondary)
            if !cloud.setupReady {
                Text("Finish steps 1 and 2 first. 请先完成第 1、2 步。")
                    .font(.footnote).foregroundStyle(Brand.clay)
            }
        }
        if !cloud.availableFamilies.isEmpty {
            Section("Available families · 可连接家庭") {
                ForEach(cloud.availableFamilies) { family in
                    Button(family.name) { familyToJoin = family; showJoinConfirmation = true }
                        .disabled(cloud.isBusy)
                }
            }
        }
    }

    @ViewBuilder private func step(_ number: Int, _ en: String, _ zh: String,
                                   _ check: FamilyCloudController.SetupCheck) -> some View {
        HStack(alignment: .top, spacing: 12) {
            switch check {
            case .ready: Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.protein)
            case .blocked: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Brand.clay)
            case .checking: ProgressView().controlSize(.small).frame(width: 20)
            case .unchecked: Image(systemName: "\(number).circle").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(number) · \(en) · \(zh)").font(.subheadline)
                if let detail = check.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    var body: some View {
        List {
            Section("iCloud family · iCloud 家庭") {
                Label(cloud.connected ? "Family connected · 已连接家庭" : "Local kitchen · 本机厨房",
                      systemImage: cloud.connected ? "person.2.fill" : "iphone")
                Text(cloud.status).font(.subheadline).foregroundStyle(.secondary)
                if cloud.isBusy { ProgressView("Connecting · 连接中") }
                if let error = cloud.error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            if cloud.connected {
                Section {
                    if let session = cloud.session, !cloud.accessBlocked {
                        LabeledContent("Your role · 你的权限", value: session.isOwner ? "Owner · 所有者" : (cloud.canWrite ? "Can edit · 可编辑" : "View only · 仅查看"))
                    }
                    if !cloud.identityConfirmed && !cloud.accessBlocked {
                        Text("Not checked with iCloud since the app opened — you are looking at this iPhone's copy. Changes are kept here and go up once it can be reached. 本次打开后尚未与 iCloud 核对，当前显示本机副本；修改会先保存在本机，能连上后再上传。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Sync now · 立即同步") { Task { await cloud.sync() } }
                        .disabled(cloud.isBusy || cloud.conflict)
                    Button("Invite & manage members · 邀请与管理成员") { Task { await cloud.manageSharing() } }
                        .disabled(cloud.isBusy || cloud.accessBlocked)
                } footer: {
                    Text("Use the system sharing panel to invite people, remove access or leave the family. Invitations are private. 系统共享面板可邀请成员、移除权限或退出家庭。")
                }
                if cloud.conflict && !cloud.accessBlocked {
                    Section("Resolve changes · 处理冲突") {
                        Text("Another device changed the same data. Both versions are backed up on this iPhone before you choose. 其他设备修改了相同数据；选择前会备份两个版本。")
                        Button("Use cloud version · 使用云端版本") { cloud.resolveConflict(useCloud: true) }
                        Button("Keep this device's version · 保留本机版本") { keepDeviceVersion = true }
                            .disabled(!cloud.canWrite)
                    }
                }
                Section {
                    Button("Return to local kitchen · 返回本机厨房", role: .destructive) { confirmDisconnect = true }
                        .disabled(cloud.isBusy)
                } footer: {
                    Text("Restores the kitchen saved before connecting. This device's shared copy is backed up, including unsynced edits. It does not remove cloud membership. 恢复连接前的本机厨房，并备份共享副本；不会退出云端家庭。")
                }
            } else {
                setup
            }
            Section("Rescue copies · 本机备份") {
                Text(cloud.backupCount == 0
                     ? "None yet. One is saved before connecting, before disconnecting and before resolving a clash. 暂无。连接、断开与处理冲突前都会各存一份。"
                     : "\(cloud.backupCount) kept on this iPhone, newest first; the oldest are dropped past \(FamilyCloudController.backupsKept). They are never uploaded. 本机保留 \(cloud.backupCount) 份，超过 \(FamilyCloudController.backupsKept) 份后删除最旧的；不会上传。")
            }.font(.footnote)
            Section("Shared with your family · 共享内容") {
                Text("Menus, shopping, stock, recipes, family settings and meal history. 菜单、采购、库存、菜谱、家庭资料与用餐记录。")
                Text("Photos, voice recordings, language and appearance are not uploaded. 照片、语音录音、语言与外观设置不上传。")
                Text("Uses your iPhone's iCloud account; no separate password. One connected family per device. 使用系统 iCloud 账号，无需另设密码；每台设备连接一个家庭。")
            }.font(.footnote)
        }
        .navigationTitle("Family sharing · 家庭共享")
        .task { if !cloud.connected { await cloud.runSetupChecks() } }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $cloud.sharePresentation) { presentation in
            FamilyCloudSharingSheet(presentation: presentation, cloud: cloud)
        }
        .alert("Create a shared family? · 创建共享家庭？", isPresented: $confirmCreate) {
            Button("Create · 创建") { Task { await cloud.createFamily() } }
            Button("Cancel · 取消", role: .cancel) {}
        } message: { Text("Your current kitchen data will be uploaded to your private iCloud storage. Only invited people can access it. The local kitchen is preserved. 当前厨房将上传到私人 iCloud，供受邀成员访问；本机厨房会保留。") }
        .alert("Connect to this family? · 连接此家庭？", isPresented: $showJoinConfirmation) {
            Button("Connect · 连接") { if let familyToJoin { Task { await cloud.connect(familyToJoin) } } }
            Button("Cancel · 取消", role: .cancel) { familyToJoin = nil }
        } message: { Text("The family kitchen will replace the view on this device. Your local kitchen is preserved separately; the two are not merged. 显示此家庭的数据；原本机厨房单独保留，不自动混合。") }
        .alert("Return to local kitchen? · 返回本机厨房？", isPresented: $confirmDisconnect) {
            Button("Return · 返回", role: .destructive) { cloud.returnToLocalKitchen() }
            Button("Cancel · 取消", role: .cancel) {}
        } message: { Text("The shared copy will be backed up, and this device will stop syncing it. Cloud data and membership are unchanged. 备份共享副本，停止本机同步；云端数据和成员关系保留。") }
        .alert("Replace the cloud version? · 替换云端版本？", isPresented: $keepDeviceVersion) {
            Button("Keep device version · 保留本机版本", role: .destructive) { cloud.resolveConflict(useCloud: false) }
            Button("Cancel · 取消", role: .cancel) {}
        } message: { Text("This explicitly replaces the shared kitchen with this device's copy on the next successful sync. Other members will receive it. 下次同步成功后，家庭成员会收到本机版本。") }
    }
}

struct FamilyCloudSharingSheet: UIViewControllerRepresentable {
    let presentation: FamilyCloudController.SharePresentation
    let cloud: FamilyCloudController
    func makeCoordinator() -> Coordinator { Coordinator(cloud: cloud) }
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: presentation.share, container: presentation.container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let cloud: FamilyCloudController
        init(cloud: FamilyCloudController) { self.cloud = cloud }
        func itemTitle(for csc: UICloudSharingController) -> String? { "Family Kitchen · 家庭厨房" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in cloud.error = error.localizedDescription }
        }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            Task { @MainActor in await cloud.sync() }
        }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in
                cloud.sharePresentation = nil
                await cloud.sync()
            }
        }
    }
}

struct FamilyInvitationView: View {
    let invitation: FamilyInvitationInbox.Invitation
    @ObservedObject var cloud: FamilyCloudController
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Join this family? · 加入这个家庭？").font(.headline)
                    Text("Its menu, shopping and stock will appear on this iPhone. Your current local kitchen is preserved separately. 将显示该家庭的菜单、采购与库存；原本机厨房单独保留。")
                    if cloud.connected { Text("Return to your local kitchen in Family sharing before joining another family. 请先在家庭共享中返回本机厨房，再加入其他家庭。").foregroundStyle(.orange) }
                    if let error = cloud.error { Text(error).foregroundStyle(.red) }
                    if cloud.isBusy { ProgressView() }
                    Button("Join family · 加入家庭") {
                        Task { await cloud.accept(invitation.metadata); if cloud.connected && cloud.error == nil { dismiss() } }
                    }.disabled(cloud.connected || cloud.isBusy || cloud.loadError != nil)
                }
            }.navigationTitle("Family invitation · 家庭邀请")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel · 取消") { dismiss() }.disabled(cloud.isBusy) } }
        }.interactiveDismissDisabled(cloud.isBusy)
    }
}
