//
//  NYWebViewReusePool.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/8/1.
//  Copyright © 2019 陈良静. All rights reserved.
//

import Foundation
import WebKit

protocol ReuseWebViewProtocol {
    func willReuse()
    func endReuse()
}

@objc public class WebViewReusePool: NSObject {
    @objc public static let shared = WebViewReusePool()
    @objc public var defaultConfigeration: WKWebViewConfiguration {
        get {
            let config = WKWebViewConfiguration.init()
            let preferences = WKPreferences.init()
            preferences.javaScriptCanOpenWindowsAutomatically = true
            config.preferences = preferences
            if #available(iOS 11.0, *) {
                // 校验自定义 customScheme 是否已经可用，没有注册过才能使用
                guard let _ =  config.urlSchemeHandler(forURLScheme: "customScheme") else {
                               config.setURLSchemeHandler(CustomURLSchemeHandler(), forURLScheme: "customScheme")
                    return config
                }
     
            }
            
            return config
        }
    }
    
    var visiableWebViewSet = Set<ReuseWebView>()
    var reusableWebViewSet = Set<ReuseWebView>()
    
    /// 线程锁
    var lock = DispatchSemaphore(value: 1)
    
    // MARK: - lifeCycle
    @objc public static func swiftyLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishLaunchingNotification), name: UIApplication.didFinishLaunchingNotification, object: nil)
    }
    
    override init() {
        super.init()
        
        // 内存警告
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarningNotification), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didFinishLaunchingNotification, object: nil)
    }
    
    @objc static func didFinishLaunchingNotification() {
        // 预先初始化webview
        WebViewReusePool.shared.prepareWebView()
    }
    
    @objc func didReceiveMemoryWarningNotification() {
        clearReusableWebViews()
    }
    
    func prepareWebView() {
        DispatchQueue.main.async {
            let webView = ReuseWebView(frame: CGRect.zero, configuration: self.defaultConfigeration)
            self.reusableWebViewSet.insert(webView)
        }
    }
    
    func tryCompactWeakHolders() {
        lock.wait()
        var shouldreusedWebViewSet = Set<ReuseWebView>()
        for webView in visiableWebViewSet {
            guard let _ = webView.holdObject else {
                shouldreusedWebViewSet.insert(webView)
                continue
            }
        }
        
        for webView in shouldreusedWebViewSet {
            webView.endReuse()
            visiableWebViewSet.remove(webView)
            reusableWebViewSet.insert(webView)
        }
        
        lock.signal()
    }
}

// MARK: - 复用池操作
extension WebViewReusePool {
    @objc public func getReusedWebView(ForHolder holder: AnyObject?) -> ReuseWebView? {
        guard let holder = holder else { return nil }
        
        tryCompactWeakHolders()
        let webView: ReuseWebView
        lock.wait()
        if reusableWebViewSet.count > 0 {
            webView = reusableWebViewSet.randomElement()!
            reusableWebViewSet.remove(webView)
            visiableWebViewSet.insert(webView)
            webView.willReuse()
        } else {
            webView = ReuseWebView(frame: CGRect.zero, configuration: defaultConfigeration)
            visiableWebViewSet.insert(webView)
        }
        
        webView.holdObject = holder
        lock.signal()
        
        return webView
    }
    
    @objc func recycleReusedWebView(_ webView: ReuseWebView?) {
        guard let webView = webView else { return }
        
        lock.wait()
        if visiableWebViewSet.contains(webView) {
            webView.endReuse()
            visiableWebViewSet.remove(webView)
            reusableWebViewSet.insert(webView)
        }
        
        lock.signal()
    }
    
    @objc func clearReusableWebViews() {
        lock.wait()
        reusableWebViewSet.removeAll()
        lock.signal()
        ReuseWebView.clearAllWebCache()
    }
}
