import Foundation
import Vision
import UIKit
import ImageIO
import AVFoundation

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
    /// A photo straight from the camera is far larger than the classifier needs, and
    /// a full-size image costs seconds and a memory spike for no extra accuracy.
    static let workingSize: CGFloat = 1024

    func labels(from image: Data) async throws -> [(label: String, confidence: Double)] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNClassifyImageRequest()
                    let handler = try Self.handler(for: image)
                    try handler.perform([request])
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

    /// Scales the photo down before it reaches Vision, honouring the orientation the
    /// camera recorded. Falls back to the original bytes if it cannot be decoded
    /// here — Vision may still manage, and failing early would help nobody.
    private static func handler(for image: Data) throws -> VNImageRequestHandler {
        guard let source = CGImageSourceCreateWithData(image as CFData, nil),
              let scaled = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: workingSize
              ] as CFDictionary)
        else { return VNImageRequestHandler(data: image, options: [:]) }
        return VNImageRequestHandler(cgImage: scaled, options: [:])
    }
}

/// What the app is allowed to do with the camera right now, asked once rather than
/// on every redraw.
enum CameraAccess {
    /// `isSourceTypeAvailable` is not free, and a SwiftUI body is evaluated on every
    /// keystroke. Asking the system once at launch is enough: a phone does not grow
    /// a camera while the app is running.
    static let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)

    /// Whether the family has already said yes. When they have, the camera can be
    /// opened straight away instead of going through an async permission round-trip
    /// that has nothing left to ask.
    static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    static var isDenied: Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .denied || status == .restricted
    }
}
