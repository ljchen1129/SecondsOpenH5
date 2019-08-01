//
//  NYWebViewReusePool.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/8/1.
//  Copyright © 2019 陈良静. All rights reserved.
//

import Foundation

protocol NYReuseWebViewProtocol {
    func willReuse()
    func endReuse()
}

let kURLScheme = "customscheme"

public class NYWebViewReusePool: NSObject {
    public static let instance = NYWebViewReusePool()
    
    var configeration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration.init()
        config.setURLSchemeHandler(NYCustomURLSchemeHandler(), forURLScheme: kURLScheme)
        return config
    }
    
    var visiableWebViewSet = Set<NYReuseWebView>()
    var reusableWebViewSet = Set<NYReuseWebView>()
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
        NYWebViewReusePool.instance.prepareWebView()
    }
    
    @objc func didReceiveMemoryWarningNotification() {
        clearReusableWebViews()
    }
    
    func prepareWebView() {
        let webView = NYReuseWebView(frame: CGRect.zero, configuration: configeration)
        reusableWebViewSet.insert(webView)
    }
    
    func tryCompactWeakHolders() {
        lock.wait()
        var shouldreusedWebViewSet = Set<NYReuseWebView>()
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
extension NYWebViewReusePool {
    public func getReusedWebView(ForHolder holder: AnyObject?) -> NYReuseWebView? {
        guard let holder = holder else { return nil }
        
        tryCompactWeakHolders()
        let webView: NYReuseWebView
        lock.wait()
        if reusableWebViewSet.count > 0 {
            webView = reusableWebViewSet.randomElement()!
            reusableWebViewSet.remove(webView)
            visiableWebViewSet.insert(webView)
            webView.willReuse()
        } else {
            webView = NYReuseWebView(frame: CGRect.zero, configuration: configeration)
            visiableWebViewSet.insert(webView)
        }
        
        webView.holdObject = holder
        lock.signal()
        
        return webView
    }
    
    func recycleReusedWebView(_ webView: NYReuseWebView?) {
        guard let webView = webView else { return }
        
        lock.wait()
        if visiableWebViewSet.contains(webView) {
            webView.endReuse()
            visiableWebViewSet.remove(webView)
            reusableWebViewSet.insert(webView)
        }
        
        lock.signal()
    }
    
    func clearReusableWebViews() {
        lock.wait()
        reusableWebViewSet.removeAll()
        lock.signal()
        NYReuseWebView.clearAllWebCache()
    }
}
