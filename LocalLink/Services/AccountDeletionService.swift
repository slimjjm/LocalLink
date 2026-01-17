import FirebaseAuth
import FirebaseFirestore

final class AccountDeletionService {

    private let db = Firestore.firestore()

    func deleteAccount(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(
                domain: "DeleteAccount",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]
            )))
            return
        }

        let uid = user.uid

        // STEP 1: Anonymise bookings (do NOT delete)
        db.collection("bookings")
            .whereField("customerId", isEqualTo: uid)
            .getDocuments { snapshot, error in

                if let error = error {
                    completion(.failure(error))
                    return
                }

                let batch = self.db.batch()

                snapshot?.documents.forEach { doc in
                    batch.updateData([
                        "customerName": "Deleted user"
                    ], forDocument: doc.reference)
                }

                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    // STEP 2: Delete Firestore user document
                    self.db.collection("users")
                        .document(uid)
                        .delete { error in

                            if let error = error {
                                completion(.failure(error))
                                return
                            }

                            // STEP 3: Delete Auth account
                            user.delete { error in
                                if let error = error {
                                    completion(.failure(error))
                                } else {
                                    completion(.success(()))
                                }
                            }
                        }
                }
            }
    }
}
