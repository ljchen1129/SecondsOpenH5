//
//  NYWebView.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/8/1.
//  Copyright © 2019 陈良静. All rights reserved.
//

import Foundation
import WebKit

@objc public class ReuseWebView: WKWebView {
    weak var holdObject: AnyObject?
    
    static func clearAllWebCache() {
        let dataTypes = [WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeCookies, WKWebsiteDataTypeSessionStorage, WKWebsiteDataTypeOfflineWebApplicationCache, WKWebsiteDataTypeOfflineWebApplicationCache, WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeIndexedDBDatabases, WKWebsiteDataTypeWebSQLDatabases]
        let websiteDataTypes = Set(dataTypes)
        let dateFrom = Date(timeIntervalSince1970: 0)
        
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: dateFrom) {
            
        }
    }
    
    deinit {
        
        //清除UserScript
        configuration.userContentController.removeAllUserScripts()
        //停止加载
        stopLoading()

        uiDelegate = nil
        navigationDelegate = nil
        // 持有者置为nil
        holdObject = nil
        print("WKWebView 销毁了！！！")
    }
}

extension ReuseWebView: ReuseWebViewProtocol {
    func willReuse() {
        
    }
    
    func endReuse() {
        holdObject = nil
        scrollView.delegate = nil
        stopLoading()
        navigationDelegate = nil
        uiDelegate = nil
        loadHTMLString("", baseURL: nil)
    }
}
