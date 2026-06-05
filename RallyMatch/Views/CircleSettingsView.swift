import SwiftUI

struct CircleSettingsView: View {
    let circle: CloudCircle

    @Bindable private var roster = CircleRosterRepository.shared

    var body: some View {
        Form {
            Section {
                InviteCodeCopyRow(code: circle.circleCode)
            } header: {
                Text("招待コード")
            } footer: {
                Text("コードをタップするとコピーできます。このコードを共有すると、同じサークルに参加できます。")
            }

            Section {
                LabeledContent("名前", value: circle.name)
                LabeledContent("競技", value: circle.sportName.isEmpty ? "—" : circle.sportName)
                if !circle.location.isEmpty {
                    LabeledContent("活動場所", value: circle.location)
                }
                if !circle.description.isEmpty {
                    LabeledContent("説明", value: circle.description)
                }
                LabeledContent("メンバー数", value: "\(circle.memberCount) 人")
                LabeledContent("登録参加者", value: "\(roster.players(for: circle.id).count) 名")
            } header: {
                Text("サークル情報")
            } footer: {
                Text("サークルの削除は Circle タブのオーナー操作から行えます。")
            }
        }
        .navigationTitle("サークル情報")
        .navigationBarTitleDisplayMode(.inline)
    }
}
