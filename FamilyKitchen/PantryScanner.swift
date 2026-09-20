import Foundation
import Vision

/// Reads a photo on this iPhone and says what it appears to contain.
///
/// Apple's general image classifier does the work, which means nothing leaves the
/// device, there is no account and no bill. The price is a general vocabulary: it
/// knows a banana and a carton of milk, and it is vague about a box of orzo. That is
/// why the shop check asks a narrow question — of the things on your list, which are
/// already at home — and why every answer is confirmed by a person.
struct VisionPantryRecognizer: PantryRecognizing {
    /// Labels below this are noise; the classifier returns hundreds per image.
    static let floor: Float = 0.05

    func labels(from image: Data) async throws -> [(label: String, confidence: Double)] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                do {
                    try VNImageRequestHandler(data: image, options: [:]).perform([request])
                    let observations = (request.results ?? [])
                        .filter { $0.confidence >= Self.floor }
                        .map { (label: $0.identifier, confidence: Double($0.confidence)) }
                    continuation.resume(returning: observations)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
