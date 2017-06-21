//
//  NewThreadViewModel.swift
//  HiPDA
//
//  Created by leizh007 on 2017/6/13.
//  Copyright © 2017年 HiPDA. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

private enum Constant {
    static let contentLengthThreshold = 5
}

enum NewThreadError: Error {
    case cannotGetTid
    case unKnown(String)
}

extension NewThreadError: CustomStringConvertible {
    var description: String {
        switch self {
        case .cannotGetTid:
            return "无法获取tid"
        case .unKnown(let value):
            return value
        }
    }
}

extension NewThreadError: LocalizedError {
    var errorDescription: String? {
        return description
    }
}

typealias NewTheadResult = HiPDA.Result<Int, NewThreadError>

class NewThreadViewModel {
    fileprivate let type: NewThreadType
    fileprivate var disposeBag = DisposeBag()
    let success: PublishSubject<Int>
    let failure: PublishSubject<String>
    let isSendButtonEnabled: Driver<Bool>
    var imageNumbers = [Int]()
    
    init(type: NewThreadType, typeName: Driver<String>, title: Driver<String>, content: Driver<String>, sendButtonPresed: PublishSubject<Void>) {
        self.type = type
        isSendButtonEnabled = Driver.combineLatest(title, content) { ($0, $1) }.map { (title, content) in
            switch type {
            case .new(fid: _):
                return !title.isEmpty && content.characters.count > Constant.contentLengthThreshold
            default:
                return content.characters.count > Constant.contentLengthThreshold
            }
        }
        success = PublishSubject<Int>()
        failure = PublishSubject<String>()
        let attribute = Driver.combineLatest(typeName, title, content) { (ForumManager.typeid(of: $0), $1, NewThreadViewModel.skinContent($2)) }
        sendButtonPresed.withLatestFrom(attribute).asObservable().subscribe(onNext: { [weak self] (typeid, title, content) in
            guard let `self` = self else { return }
            self.imageNumbers = self.imageNumbers.filter { num in
                content.contains("[attachimg]\(num)[/attachimg]")
            }
            switch type {
            case let .new(fid: fid):
                NewThreadManager.postNewThread(fid: fid, typeid: typeid, title: title, content: content, imageNumbers: self.imageNumbers, success: self.success, failure: self.failure, disposeBag: self.disposeBag)
            case let .replyPost(fid: fid, tid: tid):
                ReplyPostManager.replyPost(fid: fid, tid: tid, content: content, imageNumbers: self.imageNumbers, success: self.success, failure: self.failure, disposeBag: self.disposeBag)
            case let .replyAuthor(fid: fid, tid: tid, pid: pid):
                ReplyAuthorManager.replyAuthor(fid: fid, tid: tid, pid: pid, content: content, imageNumbers: self.imageNumbers, success: self.success, failure: self.failure, disposeBag: self.disposeBag)
            case let .quote(fid: fid, tid: tid, pid: pid):
                QuoteAuthorManager.quoteAuthor(fid: fid, tid: tid, pid: pid, content: content, imageNumbers: self.imageNumbers, success: self.success, failure: self.failure, disposeBag: self.disposeBag)
            }
        }).disposed(by: disposeBag)
    }
    
    fileprivate static func skinContent(_ content: String) -> String {
        if Settings.shared.isEnabledTail {
            if let urlString = Settings.shared.tailURL?.absoluteString, !urlString.isEmpty {
                let text = Settings.shared.tailText.isEmpty ? urlString : Settings.shared.tailText
                return "\(content)    [url=\(urlString)][size=1]\(text)[/size][/url]"
            } else if !Settings.shared.tailText.isEmpty {
                return "\(content)    [size=1]\(Settings.shared.tailText)[/size]"
            } else {
                return content
            }
        } else {
            return content
        }
    }
}