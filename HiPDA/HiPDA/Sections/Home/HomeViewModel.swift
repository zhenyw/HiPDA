//
//  HomeViewModel.swift
//  HiPDA
//
//  Created by leizh007 on 2017/4/25.
//  Copyright © 2017年 HiPDA. All rights reserved.
//

import Foundation
import RxSwift

class HomeViewModel {
    var forumNames: [String] {
        return Settings.shared.activeForumNameList
    }
    
    private var _selectedForumName: String = Settings.shared.activeForumNameList.first ?? ""
    
    var selectedForumName: String {
        get {
            if !forumNames.contains(_selectedForumName) {
                _selectedForumName = forumNames.first ?? ""
            }
            return _selectedForumName
        }
        
        set {
            _selectedForumName = newValue
        }
    }
}