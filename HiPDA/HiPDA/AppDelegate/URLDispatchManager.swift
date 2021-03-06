//
//  URLDispatchManager.swift
//  HiPDA
//
//  Created by leizh007 on 2017/6/3.
//  Copyright © 2017年 HiPDA. All rights reserved.
//

import Foundation
import SafariServices
import RxSwift
import RxCocoa

class URLDispatchManager: NSObject {
    static let shared = URLDispatchManager()
    let disposeBag = DisposeBag()
    var redirectDisposeBag = DisposeBag()
    var shouldHandlePasteBoardChanged = true
    private override init() {
        super.init()
        NotificationCenter.default.rx.notification(.UIPasteboardChanged).debounce(0.1, scheduler: MainScheduler.instance).asObservable().subscribe(onNext: { [weak self] _ in
            self?.userDidCopiedContentToPasteBoard()
        }).disposed(by: disposeBag)
        NotificationCenter.default.rx.notification(.UIApplicationDidBecomeActive).debounce(0.1, scheduler: MainScheduler.instance).asObservable().subscribe(onNext: { [weak self] _ in
            DispatchQueue.global().async {
                guard let content = UIPasteboard.general.string,
                    content.isLink,
                    let url = URL(string: content),
                    url.canOpenInAPP else { return }
                DispatchQueue.main.async {
                    self?.userDidCopiedContentToPasteBoard(autoClearContent: true)
                }
            }
        }).disposed(by: disposeBag)
    }
    
    fileprivate var topVC: UIViewController? {
        return UIApplication.topViewController()
    }
    
    func userDidCopiedContentToPasteBoard(autoClearContent: Bool = false) {
        guard shouldHandlePasteBoardChanged, Settings.shared.activeAccount != nil else {
            shouldHandlePasteBoardChanged = true
            return
        }
        guard let content = UIPasteboard.general.string else { return }
        if autoClearContent {
            UIPasteboard.general.string = ""
        }
        guard content.isLink else { return }
        let alert = UIAlertController(title: "打开链接", message: "是否打开链接： \(content)", preferredStyle: .alert)
        let confirm = UIAlertAction(title: "确定", style: .default) { [unowned self] _ in
            UIPasteboard.general.string = ""
            self.linkActived(content)
        }
        let cancel = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        alert.addAction(confirm)
        alert.addAction(cancel)
        topVC?.present(alert, animated: true, completion: nil)
    }
    
    func linkActived(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            topVC?.showPromptInformation(of: .failure("无法识别链接类型: \(urlString)"))
            return
        }
        
        switch url.linkType {
        case .external:
            openExternalURL(url)
        case .downloadAttachment:
            topVC?.showPromptInformation(of: .failure("暂不支持下载论坛附件！"))
        case .viewThread:
            openViewThread(url)
        case .redirect:
            openRedirectURL(url)
        case .userProfile:
            openUserProfile(url)
        case .internal:
            openInternal(url)
        }
    }
    
    fileprivate func show(_ viewController: UIViewController) {
        if let navi = topVC?.navigationController {
            topVC?.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            navi.pushViewController(viewController, animated: true)
        } else {
            let navi = UINavigationController(rootViewController: viewController)
            navi.transitioningDelegate = topVC as? BaseViewController
            topVC?.present(navi, animated: true, completion: nil)
        }
    }
}

// MARK: - Open URL

extension URLDispatchManager {
    fileprivate func openInternal(_ url: URL) {
        openExternalURL(url) // 暂时在浏览器中打开
        //topVC?.showPromptInformation(of: .failure("暂不支持在APP内打开该链接!"))
    }
    
    fileprivate func openViewThread(_ url: URL) {
        guard let postInfo = PostInfo(urlString: url.absoluteString) else { return }
        if let readPostVC = topVC as? PostViewController, readPostVC.canJump(to: postInfo) {
            readPostVC.jump(to: postInfo)
        } else {
            let readPostVC = PostViewController.load(from: .home)
            readPostVC.postInfo = postInfo
            show(readPostVC)
        }
    }
    
    fileprivate func openUserProfile(_ url: URL) {
        do {
            let uid = try HtmlParser.uid(from: url.absoluteString)
            let userProfileVC = UserProfileViewController.load(from: .home)
            userProfileVC.uid = uid
            show(userProfileVC)
        } catch {
            topVC?.showPromptInformation(of: .failure("\(error)"))
        }
    }
    
    fileprivate func openRedirectURL(_ url: URL) {
        topVC?.showPromptInformation(of: .loading("正在解析链接..."))
        HiPDAProvider.manager.delegate.taskWillPerformHTTPRedirectionWithCompletion = { (sesseion, task, response, request, completion) in
            DispatchQueue.main.async {
                self.topVC?.hidePromptInformation()
                if let url = request.url?.absoluteString {
                    URLDispatchManager.shared.linkActived(url)
                }
                HiPDAProvider.manager.delegate.taskWillPerformHTTPRedirectionWithCompletion = nil
                self.redirectDisposeBag = DisposeBag()
            }
        }
        guard let index = url.absoluteString.range(of: "/forum/redirect.php?")?.lowerBound else {
            topVC?.hidePromptInformation()
            topVC?.showPromptInformation(of: .failure("链接解析错误！"))
            return
        }
        HiPDAProvider.request(.redirect(url.absoluteString.substring(from: index))).asObservable().subscribe(onNext: { [ weak self] response in
            self?.topVC?.hidePromptInformation()
            self?.topVC?.showPromptInformation(of: .failure("指定的帖子不存在或已被删除或正在被审核。"))
            self?.redirectDisposeBag = DisposeBag()
        }).disposed(by: redirectDisposeBag)
    }
    
    fileprivate func openExternalURL(_ url: URL) {
        guard let scheme = url.scheme, scheme.contains("http") || scheme.contains("https") else {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(url)
            }
            return
        }
        let safari = SFSafariViewController(url: url)
        if #available(iOS 10.0, *) {
            safari.preferredControlTintColor = C.Color.navigationBarTintColor
        }
        safari.delegate = self
        safari.transitioningDelegate = topVC as? BaseViewController
        topVC?.present(safari, animated: true, completion: nil)
    }
}

// MARK: - SFSafariViewControllerDelegate

extension URLDispatchManager: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        topVC?.dismiss(animated: true, completion: nil)
    }
}
