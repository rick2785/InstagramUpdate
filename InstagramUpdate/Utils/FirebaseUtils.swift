//
//  FirebaseUtils.swift
//  InstagramUpdate
//
//  Created by RJ Hrabowskie on 3/31/23.
//

import Foundation
import Firebase

extension Database {
    static func fetchUserWithUID(uid: String, completion: @escaping (User) -> ()) {
        print("Fetching user with uid:", uid)
        
        Database.database().reference().child("users").child(uid).observeSingleEvent(of: .value, with: { snapshot in

            guard let userDictionary = snapshot.value as? [String: Any] else { return }

            let user = User(uid: uid, dictionary: userDictionary)
            completion(user)
        }) { err in
            print("Failed to fetch user for posts:", err)
        }
    }
}
