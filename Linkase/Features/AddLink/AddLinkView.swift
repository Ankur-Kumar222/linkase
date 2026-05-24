import SwiftUI

struct AddLinkView: View {
    @Environment(\.container) private var container
    @State private var viewModel: AddLinkViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = AddLinkViewModel(ingestor: container.ingestor)
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: AddLinkViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("Paste a URL", text: Binding(get: { vm.input }, set: { vm.input = $0 }))
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await vm.submit() } }
                #if os(iOS)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                #endif
                if case .working = vm.phase {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Add") { Task { await vm.submit() } }
                        .disabled(vm.input.trimmingCharacters(in: .whitespaces).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            switch vm.phase {
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            case .manualEntry(let prefill):
                ManualEntryForm(
                    prefill: prefill,
                    onCancel: { vm.cancelManual() },
                    onSave: { title, desc, tags in
                        await vm.saveManual(title: title, description: desc, tagsCSV: tags)
                    }
                )
            default:
                EmptyView()
            }
        }
    }
}
