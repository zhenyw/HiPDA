//
//  LoginViewController.swift
//  HiPDA
//
//  Created by leizh007 on 16/9/3.
//  Copyright © 2016年 HiPDA. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

/// 动画block
private typealias AnimationBlock = () -> Void

/// 动画持续时间
private let kAnimationDuration = 0.25

/// 默认的容器视图的顶部constraint
private let kDefaultContainerTopConstraintValue = CGFloat(44.0)

/// 登录的ViewController
class LoginViewController: UIViewController, StoryboardLoadable {
    /// disposeBag
    private let _disposeBag = DisposeBag()
    
    /// 分割线的高度constriant
    @IBOutlet private var seperatorsHeightConstraint: [NSLayoutConstraint]!
    
    /// 点击背景的手势识别
    @IBOutlet private var tapBackground: UITapGestureRecognizer!
    
    /// 显示更多用户名被点击
    @IBOutlet private var tapShowMoreName: UITapGestureRecognizer!
    
    /// 显示密码被点击
    @IBOutlet private var tapShowPassword: UITapGestureRecognizer!
    
    /// 显示更多用户名的imageView
    @IBOutlet private weak var showMoreNameImageView: UIImageView!
    
    /// 输入密码的TextField
    @IBOutlet private weak var passwordTextField: UITextField!
    
    /// 隐藏显示密码的ImageView
    @IBOutlet private weak var hidePasswordImageView: UIImageView!
    
    /// 输入姓名的TextField
    @IBOutlet private weak var nameTextField: UITextField!
    
    /// 输入答案的TextField
    @IBOutlet private weak var answerTextField: UITextField!
    
    /// 安全问题Button
    @IBOutlet private weak var questionButton: UIButton!
    
    /// 是否可取消
    var cancelable = false
    
    /// 取消按钮
    @IBOutlet private weak var cancelButton: UIButton!
    
    /// 安全问题的driver
    private var questionDriver: Driver<Int>!
    
    /// 登录按钮
    @IBOutlet private weak var loginButton: UIButton!
    
    /// 容器视图的顶部constraint
    @IBOutlet private weak var containerTopConstraint: NSLayoutConstraint!
    
    /// 执行动画的block
    private var animationBlock: AnimationBlock?
    
    /// tableView的高度constraint
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    
    /// 展示name的tableView
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for heightConstraint in seperatorsHeightConstraint {
            heightConstraint.constant = 1.0 / UIScreen.main.scale
        }
        cancelButton.isHidden = !cancelable
        
        configureKeyboard()
        configureQuestionButton()
        configureTapGestureRecognizer()
        configureTextFields()
        configureViewModel()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - private method
    
    /// 设置手势识别
    private func configureTapGestureRecognizer() {
        tapShowMoreName.rx.event.subscribe(onNext: { [weak self] _ in
            guard let `self` = self else { return }
            guard let textField = self.activeTextField() else {
                self.showMoreNameImageView.rotate(angle: M_PI, delay: 0.0, duration: kAnimationDuration)
                UIView.animate(withDuration: kAnimationDuration, animations: { 
                    self.tableView.isHidden = !self.tableView.isHidden
                })
                return
            }
            self.animationBlock = { [weak self] in
                guard let `self` = self else { return }
                delay(seconds: kAnimationDuration, completion: { 
                    self.showMoreNameImageView.rotate(angle: M_PI, delay: 0.0, duration: kAnimationDuration)
                    UIView.animate(withDuration: kAnimationDuration, animations: {
                        self.tableView.isHidden = !self.tableView.isHidden
                    })
                })
            }
            textField.resignFirstResponder()
         }).addDisposableTo(_disposeBag)
        
        tapShowPassword.rx.event.subscribe(onNext: { [weak self] _ in
            guard let `self` = self else { return }
            let isSecureTextEntry = self.passwordTextField.isSecureTextEntry
            self.passwordTextField.isSecureTextEntry = !isSecureTextEntry
            let image: UIImage
            switch isSecureTextEntry {
            case true:
                image = #imageLiteral(resourceName: "login_password_show")
            case false:
                image = #imageLiteral(resourceName: "login_password_hide")
            }
            
            guard let textField = self.activeTextField() else {
                UIView.transition(with: self.hidePasswordImageView,
                                  duration: kAnimationDuration,
                                  options: .transitionCrossDissolve,
                                  animations: {
                                    self.hidePasswordImageView.image = image
                    }, completion: nil)
                return
            }
            
            self.animationBlock = { [weak self] in
                guard let `self` = self else { return }
                delay(seconds: kAnimationDuration, completion: { 
                    UIView.transition(with: self.hidePasswordImageView,
                                      duration: kAnimationDuration,
                                      options: .transitionCrossDissolve,
                                      animations: {
                                        self.hidePasswordImageView.image = image
                        }, completion: nil)
                })
            }
            textField.resignFirstResponder()
        }).addDisposableTo(_disposeBag)
    }
    
    /// 设置TextFields
    private func configureTextFields() {
        let textValue = Variable("")
        _ = passwordTextField.rx.textInput <-> textValue
        textValue.asObservable().map { $0.characters.count == 0 }
            .bindTo(hidePasswordImageView.rx.hidden).addDisposableTo(_disposeBag)
        passwordTextField.rx.controlEvent(.editingDidEndOnExit).subscribe(onNext: { [weak self] _ in
            self?.answerTextField.becomeFirstResponder()
        }).addDisposableTo(_disposeBag)
        
        let editingDidBeginEvents: [Observable<Void>] = [
            nameTextField.rx.controlEvent(.editingDidBegin).map { _ in () },
            passwordTextField.rx.controlEvent(.editingDidBegin).map { _ in () },
            answerTextField.rx.controlEvent(.editingDidBegin).map { _ in () },
            questionButton.rx.tap.map { _ in () },
            loginButton.rx.tap.map { _ in () }
        ]
        
        Observable.from(editingDidBeginEvents).merge().subscribe(onNext: { [weak self] _ in
            self?.hideNameList()
        }).addDisposableTo(_disposeBag)
        
        nameTextField.rx.controlEvent(.editingDidEndOnExit).subscribe(onNext: { [weak self] _ in
            self?.passwordTextField.becomeFirstResponder()
        }).addDisposableTo(_disposeBag)
        
        answerTextField.rx.controlEvent(.editingDidEndOnExit).subscribe(onNext: { [weak self] _ in
            self?.answerTextField.resignFirstResponder()
        }).addDisposableTo(_disposeBag)
    }
    
    /// 配置安全问题的Button
    private func configureQuestionButton() {
        let questionVariable = Variable(0)
        
        questionButton.rx.tap.subscribe(onNext: { [weak self] _ in
            guard let `self` = self else { return }
            let questions = LoginViewModel.questions
            let pickerActionSheetController = PickerActionSheetController.load(from: UIStoryboard.main)
            pickerActionSheetController.pickerTitles = questions
            pickerActionSheetController.initialSelelctionIndex = questions.index(of: self.questionButton.title(for: .normal)!)
            pickerActionSheetController.selectedCompletionHandler = { [unowned self] (index) in
                self.dismiss(animated: false, completion: nil)
                if let index = index, let title = questions.safe[index] {
                    self.questionButton.setTitle(title, for: .normal)
                    questionVariable.value = index
                }
            }
            pickerActionSheetController.modalPresentationStyle = .overCurrentContext
            self.present(pickerActionSheetController, animated: false, completion: nil)
        }).addDisposableTo(_disposeBag)
        
        questionDriver = questionVariable.asDriver()
        questionDriver.drive(onNext: { [weak self] (index) in
            guard let `self` = self else { return }
            if index == 0 {
                self.answerTextField.isEnabled = false
                self.passwordTextField.returnKeyType = .done
            } else {
                self.answerTextField.isEnabled = true
                self.passwordTextField.returnKeyType = .next
            }
            self.answerTextField.text = ""
        }).addDisposableTo(_disposeBag)
    }
    
    /// 处理键盘相关
    private func configureKeyboard() {
        let dismissEvents: [Observable<Void>] = [
            tapBackground.rx.event.map { _ in () },
            // 下面两个会导致动画和键盘的动画冲突了，单独处理！
            //tapShowMoreName.rx.event.map { _ in () },
            //tapShowPassword.rx.event.map { _ in () },
            questionButton.rx.tap.map { _ in () },
            cancelButton.rx.tap.map { _ in () },
            loginButton.rx.tap.map { _ in () }
        ]
        
        Observable.from(dismissEvents).merge().subscribe(onNext: { [weak self] _ in
            self?.nameTextField.resignFirstResponder()
            self?.passwordTextField.resignFirstResponder()
            self?.answerTextField.resignFirstResponder()
        }).addDisposableTo(_disposeBag)
        
        KeyboardManager.shared.keyboardChanged.drive(onNext: { [weak self, unowned keyboardManager = KeyboardManager.shared] transition in
            guard let `self` = self else { return }
            self.animationBlock?()
            self.animationBlock = nil
            guard transition.toVisible.boolValue else {
                self.containerTopConstraint.constant = kDefaultContainerTopConstraintValue
                UIView.animate(withDuration: transition.animationDuration, delay: 0.0, options: transition.animationOption, animations: { 
                    self.view.layoutIfNeeded()
                }, completion: nil)
                return
            }
            guard let textField = self.activeTextField() else { return }
            let keyboardFrame = keyboardManager.convert(transition.toFrame, to: self.view)
            let textFieldFrame = textField.convert(textField.frame, to: self.view)
            let heightGap = textFieldFrame.origin.y + textFieldFrame.size.height - keyboardFrame.origin.y
            let containerTopConstraintConstant = heightGap > 0 ? self.containerTopConstraint.constant - heightGap : kDefaultContainerTopConstraintValue
            self.containerTopConstraint.constant = containerTopConstraintConstant
            UIView.animate(withDuration: transition.animationDuration, delay: 0.0, options: transition.animationOption, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        }).addDisposableTo(_disposeBag)
    }
    
    /// 配置ViewModel相关信息
    func configureViewModel() {
        // FIXME: - fix login view mdel initialization
        let viewModel = LoginViewModel(username: nameTextField.rx.text.asDriver(),
                                       password: passwordTextField.rx.text.asDriver(),
                                       question: questionDriver,
                                       answer: answerTextField.rx.text.asDriver())
        showMoreNameImageView.isHidden = viewModel.isShowMoreNameImageViewHidden
        viewModel.loginEnabled.drive(loginButton.rx.enabled).addDisposableTo(_disposeBag)
        
        tableViewHeightConstraint.constant = CGFloat(viewModel.tableViewHeight)
        tableView.rowHeight = 40.0
        Observable.just(viewModel.names).bindTo(tableView.rx.items(cellIdentifier: LoginNameTableViewCell.reuseIdentifier, cellType: LoginNameTableViewCell.self)) { (_, element, cell) in
            cell.name = element
        }.addDisposableTo(_disposeBag)
        tableView.rx.modelSelected(String.self).asDriver().drive(onNext: { [weak self] value in
            console(message: value)
            self?.hideNameList()
            self?.nameTextField.rx.text.onNext(value)
        }).addDisposableTo(_disposeBag)
    }
    
    /// 找到激活的textField
    ///
    /// - returns: 返回first responser的textField
    private func activeTextField() -> UITextField? {
        for textField in [nameTextField, passwordTextField, answerTextField] {
            if textField!.isFirstResponder {
                return textField
            }
        }
        
        return nil
    }
    
    /// 隐藏用户名列表
    private func hideNameList() {
        showMoreNameImageView.rotate(to: .identity, delay: 0.0, duration: kAnimationDuration)
        UIView.animate(withDuration: kAnimationDuration) { 
            self.tableView.isHidden = true
        }
    }
}
