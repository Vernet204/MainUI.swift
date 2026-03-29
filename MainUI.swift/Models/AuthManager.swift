import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

class AuthManager: ObservableObject {

    @Published var appUser: AppUser? = nil
    @Published var isLoading: Bool = true

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthState()
        try? Auth.auth().signOut() // TEMPORARY - remove after confirming flow works
        listenToAuthState()
    }

    // MARK: - Listen for Firebase Auth changes
    func listenToAuthState() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }

            if let firebaseUser = firebaseUser {
                print("✅ Auth state: user found - \(firebaseUser.uid)")
                self.fetchUserProfile(uid: firebaseUser.uid)
            } else {
                print("🚪 Auth state: no user")
                DispatchQueue.main.async {
                    self.appUser = nil
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Fetch Firestore Profile
    func fetchUserProfile(uid: String) {
        print("🔍 Fetching profile for UID: \(uid)")

        Firestore.firestore()
            .collection("users")
            .document(uid)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Firestore error: \(error.localizedDescription)")
                        self.appUser = nil
                        self.isLoading = false
                        return
                    }

                    guard let data = snapshot?.data() else {
                        print("⚠️ No Firestore document for UID: \(uid)")
                        self.appUser = nil
                        self.isLoading = false
                        return
                    }

                    print("📄 Document data: \(data)")

                    let role = data["role"] as? String ?? ""
                    print("👤 Role fetched: \(role)")

                    self.appUser = AppUser(
                        id: UUID(),
                        name: data["name"] as? String ?? "Unknown",
                        email: data["email"] as? String ?? "",
                        password: "",
                        role: role,
                        isFirstLogin: data["firstLogin"] as? Bool ?? false
                    )

                    self.isLoading = false
                }
            }
    }

    // MARK: - Login
    func login(email: String, password: String, completion: @escaping (String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                completion(error.localizedDescription)
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Logout
    func logout() {
        try? Auth.auth().signOut()
        DispatchQueue.main.async {
            self.appUser = nil
        }
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

