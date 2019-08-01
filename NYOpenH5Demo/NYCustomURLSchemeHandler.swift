//
//  NYCustomURLSchemeHandler.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/7/30.
//  Copyright © 2019 陈良静. All rights reserved.
//

import Foundation
import CoreServices
import CommonCrypto

class NYCustomURLSchemeHandler: NSObject, WKURLSchemeHandler {
    var dask: URLSessionDataTask?
    /// 防止 urlSchemeTask 实例释放了，又给他发消息导致崩溃
    var holdUrlSchemeTasks = [AnyHashable: Bool]()
    var queue = DispatchQueue(label: "holdUrlSchemeTasksQueue")
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let headers = urlSchemeTask.request.allHTTPHeaderFields
        guard let accept = headers?["Accept"] else { return }
        guard let requestUrlString = urlSchemeTask.request.url?.absoluteString else { return }
        
        if accept.count >= "text".count && accept.contains("text/html") {
            // html 拦截
            print("html = \(String(describing: requestUrlString))")
            loadLocalFile(fileName: creatCacheKey(urlSchemeTask: urlSchemeTask), urlSchemeTask: urlSchemeTask)
        } else if (requestUrlString.isJSOrCSSFile()) {
            // js || css 文件
            print("js || css = \(String(describing: requestUrlString))")
            loadLocalFile(fileName: creatCacheKey(urlSchemeTask: urlSchemeTask), urlSchemeTask: urlSchemeTask)
            
        } else if accept.count >= "image".count && accept.contains("image") {
            // 图片
            print("image = \(String(describing: requestUrlString))")
            guard let originUrlString = urlSchemeTask.request.url?.absoluteString.replacingOccurrences(of: "customscheme", with: "https") else { return }
            let key = SDWebImageManager.shared.cacheKey(for: URL(string: originUrlString))
            
            SDWebImageManager.shared.imageCache.queryImage(forKey: key, options: SDWebImageOptions.retryFailed, context: nil) { (image, data, cacheType) in
                if let image = image {
                    guard let imageData = image.jpegData(compressionQuality: 1) else { return }
                    let mimeType = self.mimeType(pathExtension: self.creatCacheKey(urlSchemeTask: urlSchemeTask)!)
                    self.resendRequset(urlSchemeTask: urlSchemeTask, mineType: mimeType, requestData: imageData)
                } else {
                    self.loadLocalFile(fileName: self.creatCacheKey(urlSchemeTask: urlSchemeTask), urlSchemeTask: urlSchemeTask)
                }
            }
            
        } else {
            // 空json
            print("空json")
            do {
                let data = try JSONSerialization.data(withJSONObject: [], options: JSONSerialization.WritingOptions.prettyPrinted)
                resendRequset(urlSchemeTask: urlSchemeTask, mineType: "text/html", requestData: data)
                
            } catch let error {
                print("json 序列化 error = \(error)")
            }
        }
    }
    
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        dask = nil
        
        queue.sync {
            holdUrlSchemeTasks[urlSchemeTask.description] = false
        }
    }
    
    
    func creatCacheKey(urlSchemeTask: WKURLSchemeTask) -> String? {
        guard let fileName = urlSchemeTask.request.url?.absoluteString.replacingOccurrences(of: "customscheme://", with: "") else { return nil }
        guard let extensionName = urlSchemeTask.request.url?.pathExtension else { return nil }
        var result = fileName.md5()
        if extensionName.count == 0 {
            result += ".html"
        } else {
            result += extensionName
        }
        
        return result
    }
    
    func loadLocalFile(fileName: String?, urlSchemeTask: WKURLSchemeTask) {
        if fileName == nil && fileName?.count == 0 { return }
        
        // 先从本地中文件中加载
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let pathUrl = cacheDir.appendingPathComponent(fileName!)
        if FileManager.default.fileExists(atPath: pathUrl.path) {
            // 缓存命中
            print("缓存命中!!!!")
            do {
                let data = try Data(contentsOf: pathUrl, options: Data.ReadingOptions.dataReadingMapped)
                resendRequset(urlSchemeTask: urlSchemeTask, mineType: mimeType(pathExtension: pathUrl.pathExtension), requestData: data)
            } catch let error {
                print("缓存读取 error = \(error)")
            }
            
        } else {
            print("没有缓存!!!!")
            // 没有缓存,替换url，重新加载
            guard let urlString = urlSchemeTask.request.url?.absoluteString.replacingOccurrences(of: "customscheme", with: "https") else { return }
            // 替换成https请求
            let request = URLRequest(url: URL(string: urlString)!)
            let session = URLSession.init(configuration: .default)
            dask = session.dataTask(with: request) { (data, response, error) in
                // urlSchemeTask 是否提前结束，结束了调用实例方法会崩溃
                if let isValid = self.holdUrlSchemeTasks[urlSchemeTask.description] {
                    if !isValid {
                        return
                    }
                }
                
                if let error = error {
                    urlSchemeTask.didFailWithError(error)
                } else {
                    urlSchemeTask.didReceive(response!)
                    urlSchemeTask.didReceive(data!)
                    urlSchemeTask.didFinish()
                    
                    guard let accept = urlSchemeTask.request.allHTTPHeaderFields?["Accept"] else { return }
                    
                    if !(accept.count > "image".count && accept.contains("image")) {
                        // 图片不下载
                        print("开始重新发送网络请求!")
                        do {
                            try data?.write(to: pathUrl, options: Data.WritingOptions.atomic)
                        } catch let error {
                            print("缓存写入 error = \(error)")
                        }
                    }
                }
            }
            
            dask?.resume()
            session.finishTasksAndInvalidate()
        }
    }
    
    //根据后缀获取对应的Mime-Type
    func mimeType(pathExtension: String) -> String {
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                           pathExtension as NSString,
                                                           nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?
                .takeRetainedValue() {
                return mimetype as String
            }
        }
        
        //文件资源类型如果不知道，传万能类型application/octet-stream，服务器会自动解析文件类
        return "application/octet-stream"
    }
    
    
    /// 重新发送请求
    ///
    /// - Parameters:
    ///   - urlSchemeTask: <#urlSchemeTask description#>
    ///   - mineType: <#mineType description#>
    ///   - requestData: <#requestData description#>
    func resendRequset(urlSchemeTask: WKURLSchemeTask, mineType: String?, requestData: Data) {
        guard let url = urlSchemeTask.request.url else { return }
        
        if let isValid = holdUrlSchemeTasks[urlSchemeTask.description] {
            if !isValid {
                return
            }
        }
        
        let mineT = mineType ?? "text/html"
        let response = URLResponse(url: url, mimeType: mineT, expectedContentLength: requestData.count, textEncodingName: nil)
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(requestData)
        urlSchemeTask.didFinish()
    }
}

extension String {
    func md5() -> String {
        let str = self.cString(using: String.Encoding.utf8)
        let strLen = CUnsignedInt(self.lengthOfBytes(using: String.Encoding.utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<UInt8>.allocate(capacity: 16)
        CC_MD5(str!, strLen, result)
        let hash = NSMutableString()
        for i in 0 ..< digestLen {
            hash.appendFormat("%02x", result[i])
        }
        free(result)
        return String(format: hash as String)
    }
    
    func isJSOrCSSFile() -> Bool {
        if self.count == 0 { return false }
        let pattern = "\\.(js|css)"
        do {
            let result = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive).matches(in: self, options: NSRegularExpression.MatchingOptions.init(rawValue: 0), range: NSRange(location: 0, length: self.count))
            return result.count > 0
        } catch {
            return false
        }
    }
}
