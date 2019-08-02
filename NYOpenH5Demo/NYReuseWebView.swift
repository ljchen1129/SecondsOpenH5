//
//  NYWebView.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/8/1.
//  Copyright © 2019 陈良静. All rights reserved.
//

import Foundation

public class NYReuseWebView: WKWebView {
    var holdObject: AnyObject?
    
    static func clearAllWebCache() {
        let dataTypes = [WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeCookies, WKWebsiteDataTypeSessionStorage, WKWebsiteDataTypeOfflineWebApplicationCache, WKWebsiteDataTypeOfflineWebApplicationCache, WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeIndexedDBDatabases, WKWebsiteDataTypeWebSQLDatabases]
        let websiteDataTypes = Set(dataTypes)
        let dateFrom = Date(timeIntervalSince1970: 0)
        
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: dateFrom) {
            
        }
    }
}

extension NYReuseWebView: NYReuseWebViewProtocol {
    func willReuse() {
        
    }
    
    func endReuse() {
        holdObject = nil
        scrollView.delegate = nil
        stopLoading()
        navigationDelegate = nil
        uiDelegate = nil
    }
}
