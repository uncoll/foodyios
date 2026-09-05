import UIKit

enum ImageProcessing {
    /// Уменьшает фото до 1600 px по длинной стороне и кодирует в JPEG — так же, как в бенчмарке.
    /// Меньше токенов и трафика, точность распознавания не страдает.
    static func prepareForUpload(_ image: UIImage, maxSide: CGFloat = 1600, quality: CGFloat = 0.88) -> Data? {
        let normalized = image.normalizedOrientation()
        let size = normalized.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// Миниатюра для карточки продукта.
    static func thumbnail(_ image: UIImage, maxSide: CGFloat = 800) -> Data? {
        prepareForUpload(image, maxSide: maxSide, quality: 0.8)
    }
}

extension UIImage {
    /// Убирает EXIF-поворот (камера отдаёт кадры с ориентацией в метаданных).
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
