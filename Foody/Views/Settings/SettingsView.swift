import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import FoodyCore

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @State private var showTargets = false
    @State private var exportFile: ExportFile?
    @State private var showImporter = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showTargets = true } label: {
                        Label("Дневные цели по КБЖУ", systemImage: "target")
                    }
                }

                AISettingsSection()

                Section {
                    Button {
                        exportBackup()
                    } label: {
                        Label("Экспортировать резервную копию", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Восстановить из копии", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Данные")
                } footer: {
                    Text("Все данные хранятся только на этом iPhone. Резервная копия — один JSON-файл со всеми продуктами, рецептами, записями и целями; его можно сохранить в «Файлы» или отправить себе.")
                }

                Section("О приложении") {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                    Text("Foody — личный дневник КБЖУ. Фото этикеток отправляются только выбранному поставщику модели и только в момент распознавания; ключи хранятся в Keychain устройства.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .sheet(isPresented: $showTargets) { TargetsView() }
            .sheet(item: $exportFile) { file in
                ShareSheet(items: [file.url])
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    importBackup(from: url)
                case .failure(let error):
                    message = error.localizedDescription
                }
            }
            .alert("Данные", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func exportBackup() {
        do {
            let data = try DataExport.makeBackup(context: context)
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Foody-backup-\(f.string(from: Date())).json")
            try data.write(to: url, options: .atomic)
            exportFile = ExportFile(url: url)
        } catch {
            message = "Не удалось создать копию: \(error.localizedDescription)"
        }
    }

    private func importBackup(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let added = try DataExport.restore(from: data, context: context)
            message = added == 0 ? "Новых записей не найдено — всё уже есть." : "Добавлено записей: \(added)."
        } catch {
            message = "Не удалось восстановить: \(error.localizedDescription)"
        }
    }
}

struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Настройки распознавания этикеток: поставщик, модель, ключ, усилие.
struct AISettingsSection: View {
    @Environment(AppSettings.self) private var settings
    @State private var customModel = ""

    var body: some View {
        @Bindable var settings = settings
        Section {
            Picker("Поставщик", selection: $settings.provider) {
                ForEach(LLMProvider.allCases) { p in Text(p.title).tag(p) }
            }
            .onChange(of: settings.provider) { _, newValue in
                if ModelCatalog.option(provider: newValue, modelID: settings.model) == nil,
                   let first = ModelCatalog.options(for: newValue).first {
                    settings.model = first.modelID
                }
            }

            Picker("Модель", selection: $settings.model) {
                ForEach(ModelCatalog.options(for: settings.provider)) { o in
                    VStack(alignment: .leading) {
                        Text(o.title)
                        Text("\(o.costLabel) · \(o.note)").font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(o.modelID)
                }
                if ModelCatalog.option(provider: settings.provider, modelID: settings.model) == nil {
                    Text(settings.model).tag(settings.model)
                }
            }
            .pickerStyle(.navigationLink)

            HStack {
                TextField("Другой id модели", text: $customModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Применить") {
                    let m = customModel.trimmingCharacters(in: .whitespaces)
                    if !m.isEmpty { settings.model = m; customModel = "" }
                }
                .disabled(customModel.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Picker("Усилие рассуждения", selection: $settings.effort) {
                Text("По умолчанию модели").tag("")
                Text("Низкое (быстро, дёшево)").tag("low")
                Text("Среднее").tag("medium")
                Text("Высокое").tag("high")
            }

            switch settings.provider {
            case .openAI:
                SecureField("OpenAI API key (sk-…)", text: $settings.openAIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            case .anthropic:
                SecureField("Anthropic API key (sk-ant-…)", text: $settings.anthropicKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Toggle("Сохранять фото этикетки в карточке", isOn: $settings.keepLabelPhoto)
        } header: {
            Text("Распознавание этикеток")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if settings.hasKey {
                    Label("Ключ сохранён в Keychain", systemImage: "checkmark.seal").foregroundStyle(Theme.accent)
                } else {
                    Text("Ключ можно получить в консоли поставщика: \(settings.provider.consoleURL)")
                }
                Text("Рекомендация по итогам бенчмарка (docs/model-analysis.md): \(ModelCatalog.recommended.title) — лучшее соотношение цены и точности; \(ModelCatalog.anthropic.last?.title ?? "Claude Opus 5") — максимальная точность на сложных фото.")
            }
        }
    }
}

/// Системный лист «Поделиться».
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
