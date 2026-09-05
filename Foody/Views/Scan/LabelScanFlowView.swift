import SwiftUI
import PhotosUI
import FoodyCore

/// Сканирование этикетки: выбор фото → распознавание моделью → форма продукта с заполненными полями.
struct LabelScanFlowView: View {
    let onSaved: (Product) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    enum Stage: Equatable {
        case choose
        case recognizing
        case review
    }

    @State private var stage: Stage = .choose
    @State private var image: UIImage?
    @State private var draft = ProductDraft()
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showAISettings = false

    var body: some View {
        Group {
            switch stage {
            case .choose:
                NavigationStack { chooser }
            case .recognizing:
                NavigationStack { recognizing }
            case .review:
                ProductFormView(mode: .create(draft)) { product in
                    onSaved(product)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { picked in
                showCamera = false
                if let picked { start(with: picked) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    photoItem = nil
                    if let data, let picked = UIImage(data: data) { start(with: picked) }
                }
            }
        }
        .alert("Не удалось распознать", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Повторить") { stage = .choose }
            Button("Ввести вручную") {
                draft = ProductDraft()
                draft.labelImage = image.flatMap { ImageProcessing.thumbnail($0) }
                stage = .review
            }
            Button("Отмена", role: .cancel) { dismiss() }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showAISettings) {
            NavigationStack {
                Form { AISettingsSection() }
                    .navigationTitle("Распознавание")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { showAISettings = false } } }
            }
        }
    }

    private var chooser: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.accent)
            VStack(spacing: 6) {
                Text("Сфотографируйте таблицу\nпищевой ценности")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Крупно, без бликов, чтобы цифры читались. Модель заполнит карточку продукта — останется проверить и сохранить.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if !settings.hasKey {
                VStack(spacing: 8) {
                    Label("Не задан API-ключ для \(settings.provider.title)", systemImage: "key")
                        .font(.footnote)
                        .foregroundStyle(Theme.over)
                    Button("Настроить распознавание") { showAISettings = true }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            } else if let option = settings.currentOption {
                Text("\(option.title) · \(option.costLabel)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(settings.model)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Снять камерой", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!settings.hasKey)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Выбрать из галереи", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(!settings.hasKey)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .padding()
        .background(Theme.background)
        .navigationTitle("Этикетка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
        }
    }

    private var recognizing: some View {
        VStack(spacing: 20) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                    .padding(.horizontal)
            }
            ProgressView()
                .controlSize(.large)
            Text("Распознаём этикетку…")
                .font(.headline)
            Text("\(settings.currentOption?.title ?? settings.model). Обычно 5–20 секунд.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 24)
        .background(Theme.background)
        .navigationTitle("Этикетка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
        }
    }

    private func start(with picked: UIImage) {
        image = picked
        stage = .recognizing
        Task {
            do {
                let result = try await LabelScanService.scan(image: picked, settings: settings)
                await MainActor.run {
                    draft = result
                    stage = .review
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
