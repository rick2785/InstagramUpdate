//
//  UserProfileHeader.swift
//  InstagramUpdate
//
//  Created by RJ Hrabowskie on 3/27/23.
//

import UIKit
import Firebase

protocol UserProfileHeaderDelegate {
    func didChangeToListView()
    func didChangeToGridView()
}

class UserProfileHeader: UICollectionViewCell {
    
    var delegate: UserProfileHeaderDelegate?
    
    var user: User? {
        didSet {
            guard let profileImageUrl = user?.profileImageUrl else { return }
            
            profileImageView.loadImage(urlString: profileImageUrl)
            
            usernameLabel.text = user?.username
            
            setupEditFollowButton()
            setupAttributedPostsAmount()
            setupAttributedFollowingAmount()
            setupAttributedFollowersAmount()
        }
    }
    var posts = [Post]()
    fileprivate func setupAttributedPostsAmount(){
        if posts.count <= 0 && !posts.isEmpty {
            postsLabel.attributedText = templateAttributedText(top: "0\n", bottom: "posts")
        }
        
        guard let uid = user?.uid else { return }
        let ref = Database.database().reference().child("posts").child(uid)
        let query = ref.queryOrdered(byChild: "creationDate")
        query.queryLimited(toLast: 4).observeSingleEvent(of: .value, with: { snapshot in
            
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
            
            self.postsLabel.attributedText = self.templateAttributedText(top: "\(allObjects.count)\n", bottom: "posts")
        }) { err in
            print("Failed to fetch ordered posts:", err)
        }
    }
    
    fileprivate func setupAttributedFollowingAmount() {
        guard let uid = user?.uid else { return }
        Database.database().reference().child("following").child(uid).observeSingleEvent(of: .value, with: { snapshot in
            
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
            
            self.following = allObjects.count
            self.followingLabel.attributedText = self.templateAttributedText(top: "\(self.following)\n", bottom: "following")
        }){ err in
            print("Failed to fetch following:", err)
        }
    }
    
    fileprivate func setupAttributedFollowersAmount() {
        guard let uid = user?.uid else { return }
        Database.database().reference().child("followers").child(uid).observeSingleEvent(of: .value, with: { snapshot in
            
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
            
            self.followers = allObjects.count
            self.followersLabel.attributedText = self.templateAttributedText(top: "\(self.followers)\n", bottom: "followers")
        }){ err in
            print("Failed to fetch followers:", err)
        }
    }
    
    fileprivate func setupEditFollowButton() {
        guard let currentLoggedInUserId = Auth.auth().currentUser?.uid else { return }
        
        guard let userId = user?.uid else { return }
        
        if currentLoggedInUserId == userId {
            editProfileFollowButton.isEnabled = false
        } else {
            
            // Check if following
            Database.database().reference().child("following").child(currentLoggedInUserId).child(userId).observeSingleEvent(of: .value, with: { snapshot in
                
                if let isFollowing = snapshot.value as? Int, isFollowing == 1 {
                    self.editProfileFollowButton.setTitle("Unfollow", for: .normal)
                } else {
                    self.setupFollowStyle()
                }
            }, withCancel: { err in
                print("Failed to check if following:", err)
            }) 
        }
    }
    
    var following: Int = 0
    var followers: Int = 0
    @objc func handleEditProfileOrFollow() {
        guard let currentLoggedInUserId = Auth.auth().currentUser?.uid else { return }
        
        guard let userId = user?.uid else { return }
        
        if editProfileFollowButton.titleLabel?.text == "Unfollow" {
            // Unfollow
            unfollowUserLogic(child: "following", uid1: currentLoggedInUserId, uid2: userId, errorMessage: "Failed to unfollow user:", successMessage: "Successfully unfollowed user: \(self.user?.username ?? "")") {
                
                self.setupFollowStyle()
                
                if self.following == 0 {
                    return
                }
                
                self.followingLabel.attributedText = self.templateAttributedText(top: "\(self.following)\n", bottom: "following")
            }
            
            unfollowUserLogic(child: "followers", uid1: userId, uid2: currentLoggedInUserId, errorMessage: "Failed to unfollow follower user:", successMessage: "Successfully unfollowed followers with user:  \(currentLoggedInUserId)") {
                
                if self.followers == 0 {
                    return
                } else {
                    self.followers -= 1
                }
                
                self.followersLabel.attributedText = self.templateAttributedText(top: "\(self.followers)\n", bottom: "followers")
            }
            
        } else {
            // Follow Logic
            followUserLogic(child: "following", Uid: currentLoggedInUserId, values: [userId: 1], errorMessage: "Failed to follow user:", successMessage: "Successfully followed user:  \(self.user?.username ?? "")") {
                
                self.editProfileFollowButton.setTitle("Unfollow", for: .normal)
                self.editProfileFollowButton.backgroundColor = .white
                self.editProfileFollowButton.setTitleColor(.label, for: .normal)
                
                self.followingLabel.attributedText = self.templateAttributedText(top: "\(self.following)\n", bottom: "following")
            }
            
            followUserLogic(child: "followers", Uid: userId, values: [currentLoggedInUserId: 1], errorMessage: "Failed followers:", successMessage: "Suceessful followers: \(currentLoggedInUserId)") {
                
                self.followers += 1
                self.followersLabel.attributedText = self.templateAttributedText(top: "\(self.followers)\n", bottom: "followers")
            }
        }
    }
    
    fileprivate func unfollowUserLogic(child: String, uid1: String, uid2: String, errorMessage: String, successMessage: String?, completion: @escaping () -> ()) {
        Database.database().reference().child(child).child(uid1).child(uid2).removeValue { err, ref in
            if let err = err {
                print(errorMessage, err)
                return
            }
            
            print(successMessage ?? "")
            completion()
        }
    }
    
    fileprivate func followUserLogic(child: String, Uid: String, values: [String: Int], errorMessage: String, successMessage: String, completion: @escaping () -> ()) {
        let ref = Database.database().reference().child(child).child(Uid)
        let values = values
        ref.updateChildValues(values) { err, ref in
            if let err = err {
                print(errorMessage, err)
                return
            }
            
            print(successMessage)
            completion()
        }
    }
    
    fileprivate func setupFollowStyle() {
        self.editProfileFollowButton.setTitle("Follow", for: .normal)
        self.editProfileFollowButton.backgroundColor = UIColor.rgb(red: 17, green: 154, blue: 237)
        self.editProfileFollowButton.setTitleColor(.systemBackground, for: .normal)
        self.editProfileFollowButton.layer.borderColor = UIColor(white: 0, alpha: 0.2).cgColor
    }
    
    let profileImageView: CustomImageView = {
        let iv = CustomImageView()
        return iv
    }()
    
    lazy var gridButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(imageLiteralResourceName: "grid"), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(handleChangeToGridView), for: .touchUpInside)
        return button
    }()
    
    @objc func handleChangeToGridView() {
        gridButton.tintColor = .mainBlue()
        listButton.tintColor = .label
        delegate?.didChangeToGridView()
    }
    
    lazy var listButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(imageLiteralResourceName: "list"), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(handleChangeToListView), for: .touchUpInside)
        return button
    }()
    
    @objc func handleChangeToListView() {
        listButton.tintColor = .mainBlue()
        gridButton.tintColor = .label
        delegate?.didChangeToListView()
    }
    
    let bookmarkButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(imageLiteralResourceName: "ribbon"), for: .normal)
        button.tintColor = .label
        return button
    }()
    
    let usernameLabel: UILabel = {
        let label = UILabel()
        label.text = "username"
        label.font = UIFont.boldSystemFont(ofSize: 14)
        return label
    }()
    
    fileprivate func templateAttributedText(top: String, bottom: String) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: top, attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14)])
        
        attributedText.append(NSAttributedString(string: bottom, attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
        
        return attributedText
    }
    
    let postsLabel: UILabel = {
        let label = UILabel()
        
        let attributedText = NSMutableAttributedString(string: "11\n", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14)])
        
        attributedText.append(NSAttributedString(string: "posts", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
    
        label.attributedText = attributedText
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    let followersLabel: UILabel = {
        let label = UILabel()
        
        let attributedText = NSMutableAttributedString(string: "0\n", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14)])
        
        attributedText.append(NSAttributedString(string: "followers", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
    
        label.attributedText = attributedText
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    let followingLabel: UILabel = {
        let label = UILabel()
        
        let attributedText = NSMutableAttributedString(string: "0\n", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14)])
        
        attributedText.append(NSAttributedString(string: "following", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
    
        label.attributedText = attributedText
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    lazy var editProfileFollowButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Edit Profile", for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 3
        button.addTarget(self, action: #selector(handleEditProfileOrFollow), for: .touchUpInside)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(profileImageView)
        profileImageView.anchor(top: topAnchor, left: leftAnchor, bottom: nil, right: nil, paddingTop: 12, paddingLeft: 12, paddingBottom: 0, paddingRight: 0, width: 80, height: 80)
        profileImageView.layer.cornerRadius = 80 / 2
        profileImageView.clipsToBounds = true
        
        setupBottomToolbar()
        
        addSubview(usernameLabel)
        usernameLabel.anchor(top: profileImageView.bottomAnchor, left: leftAnchor, bottom: gridButton.topAnchor, right: rightAnchor, paddingTop: 4, paddingLeft: 12, paddingBottom: 0, paddingRight: 12, width: 0, height: 0)
        
        setupUserStatsView()
        
        addSubview(editProfileFollowButton)
        editProfileFollowButton.anchor(top: postsLabel.bottomAnchor, left: postsLabel.leftAnchor, bottom: nil, right: followingLabel.rightAnchor, paddingTop: 2, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 34)
    }
    
    fileprivate func setupUserStatsView() {
        let stackView = UIStackView(arrangedSubviews: [postsLabel, followersLabel, followingLabel])
        stackView.distribution = .fillEqually
        
        addSubview(stackView)
        stackView.anchor(top: topAnchor, left: profileImageView.rightAnchor, bottom: nil, right: rightAnchor, paddingTop: 12, paddingLeft: 12, paddingBottom: 0, paddingRight: 12, width: 0, height: 50)
    }
    
    fileprivate func setupBottomToolbar() {
        let topDividerView = UIView()
        topDividerView.backgroundColor = UIColor.lightGray
        
        let bottomDividerView = UIView()
        topDividerView.backgroundColor = UIColor.lightGray
        
        let stackView = UIStackView(arrangedSubviews: [gridButton, listButton, bookmarkButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        
        addSubview(stackView)
        addSubview(topDividerView)
        addSubview(bottomDividerView)
        
        stackView.anchor(top: nil, left: leftAnchor, bottom: self.bottomAnchor, right: rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 50)
        
        topDividerView.anchor(top: stackView.topAnchor, left: leftAnchor, bottom: nil, right: rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 0.5)
        
        bottomDividerView.anchor(top: stackView.bottomAnchor, left: leftAnchor, bottom: nil, right: rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 0.5)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
