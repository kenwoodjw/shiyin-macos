import AppKit
import SwiftUI

struct CopyableErrorView: View {
    @Environment(\.themePalette) private var theme
    @State private var copied = false

    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(message, forType: .string)
                } label: {
                    Label(copied ? "已复制" : "复制错误", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.accentDark)
                .help("复制完整错误信息")
            }

            ScrollView {
                Text(message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 120)
        }
        .padding(10)
        .background(theme.sidebar, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.line))
        .onChange(of: message) { _, _ in copied = false }
    }
}
