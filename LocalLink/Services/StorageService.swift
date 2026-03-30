import FirebaseStorage
import UIKit

final class StorageService {

    static let shared = StorageService()
    private init() {}

    private let storage = Storage.storage()

    func uploadBusinessImage(
        businessId: String,
        image: UIImage,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            return
        }

        let filename = UUID().uuidString
        let ref = Storage.storage()
            .reference()
            .child("businessPhotos/\(businessId)/\(UUID().uuidString).jpg")

        ref.putData(data) { _, error in

            if let error {
                completion(.failure(error))
                return
            }

            ref.downloadURL { url, error in

                if let error {
                    completion(.failure(error))
                    return
                }

                guard let url = url else { return }

                completion(.success(url.absoluteString))
            }
        }
    }
}
