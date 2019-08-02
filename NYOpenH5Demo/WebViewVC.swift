//
//  WebViewVC.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/7/24.
//  Copyright © 2019 陈良静. All rights reserved.
//

import UIKit

class WebViewVC: UIViewController {
    
    var urlString: String
    var timer: DispatchSourceTimer?
    
    var lastTime: Double?
    
    lazy var webview: WKWebView = {
//        let configration = WKWebViewConfiguration.init()
//        let preferences = WKPreferences.init()
//        preferences.javaScriptCanOpenWindowsAutomatically = true
//        configration.preferences = preferences
//        configration.setURLSchemeHandler(CustomRLSchemeHandler(), forURLScheme: "customscheme")
//        let wkwebView = WKWebView(frame: CGRect.zero, configuration: configration)
//        let wkwebView = NYWebViewReusePool.shared.getReusedWebView(ForHolder: self)!
//        wkwebView.navigationDelegate = self
        
        let wkwebView = HPKPageManager.sharedInstance().dequeueWebView(with: HPKWebView.self, webViewHolder: self)!
//        wkwebView?.navigationDelegate = self
        wkwebView.addObserver(self, forKeyPath: #keyPath(HPKWebView.estimatedProgress), options: .new, context: nil)
//        let newWkwebView = HPKPageManager.sharedInstance().dequeueWebView(with: HPKWebView.self, webViewHolder: self)
//        newWkwebView?.navigationDelegate = self
//        newWkwebView?.addObserver(self, forKeyPath: #keyPath(HPKWebView.estimatedProgress), options: .new, context: nil)
        
        return wkwebView
    }()
    
    lazy var progressLine: UIProgressView = {
        let line = UIProgressView(frame: CGRect.zero)
        line.backgroundColor = UIColor.white
        line.progressTintColor = UIColor.red
        line.isHidden = true
        return line
    }()
    
    lazy var loadTimeLabel: UILabel = {
        let label = UILabel(frame: CGRect.zero)
        label.textColor = UIColor.red
        label.backgroundColor = UIColor.gray
        label.font = UIFont.systemFont(ofSize: 18)
        return label
    }()
    
    init(urlString: String) {
        self.urlString = urlString
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webview.frame = view.bounds
        view.addSubview(webview)
        progressLine.frame = CGRect(x: 0, y: 88, width: view.bounds.width, height: 1)
        view.addSubview(progressLine)
        view.bringSubviewToFront(progressLine)
        
        view.addSubview(loadTimeLabel)
        loadTimeLabel.frame = CGRect(x: 100, y: 100, width: 100, height: 50)
        view.bringSubviewToFront(loadTimeLabel)
        
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url)
        webview.load(request)
        
        
        // 开启定时器
        timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)
        timer!.schedule(deadline: .now(), repeating: DispatchTimeInterval.microseconds(1))
        lastTime = CFAbsoluteTimeGetCurrent()
        self.loadTimeLabel.text = String(format: "%.3f", lastTime!)
        timer!.setEventHandler {
            let time = CFAbsoluteTimeGetCurrent() - self.lastTime!
            self.loadTimeLabel.text = String(format: "%.3f", time)
        }
        timer?.activate()
        
        UIApplication.shared.applicationSupportsShakeToEdit = true
        self.becomeFirstResponder()
    }
    
    deinit {
       webview.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        NYWebViewReusePool.shared.recycleReusedWebView(webview as? NYReuseWebView)
        print("webVC 销毁了!!!")
    }
    
    // 观察者
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let value = change?[NSKeyValueChangeKey.newKey] as! NSNumber
        progressLine.progress = value.floatValue
    }
}


extension WebViewVC: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressLine.isHidden = false
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.title", completionHandler: { [weak self] (x, error) in
            print(x as Any)
            print(error as Any)
            self?.title = (x as! String)
        })
        
        progressLine.isHidden = true
        timer?.cancel()
        timer = nil
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(error)
    }
}

extension WebViewVC {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if event?.subtype == UIEvent.EventSubtype.motionShake {
            
            let alertVC = UIAlertController.init(title: "查看界面结构", message: "", preferredStyle: UIAlertController.Style.alert)
            alertVC.addAction(UIAlertAction(title: "导出UI结构", style: .default, handler: { (_) in
                NotificationCenter.default.post(name: NSNotification.Name.init(rawValue: "Lookin_Export"), object: nil)
            }))
            alertVC.addAction(UIAlertAction(title: "2D视图", style: .default, handler: { (_) in
                NotificationCenter.default.post(name: NSNotification.Name.init(rawValue: "Lookin_2D"), object: nil)
            }))
            alertVC.addAction(UIAlertAction(title: "3D视图", style: .default, handler: { (_) in
                NotificationCenter.default.post(name: NSNotification.Name.init(rawValue: "Lookin_3D"), object: nil)
            }))
            alertVC.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { (_) in
                
            }))
            
            self.present(alertVC, animated: true, completion: nil)
        }
    }
}

