//
//  WebViewVC.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/7/24.
//  Copyright © 2019 陈良静. All rights reserved.
//

import UIKit
import WebKit
import CoreServices

class CustomRLSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let headers = urlSchemeTask.request.allHTTPHeaderFields
        guard let accept = headers?["Accept"] else { return }
        
        let requestUrlString = urlSchemeTask.request.url?.absoluteString
//        guard let fileName = urlSchemeTask.request.url?.absoluteString.replacingOccurrences(of: "customscheme", with: "https") else { return }
//        let fileName = requestUrlString?.components(separatedBy: "?").first?.components(separatedBy: "/").last
//        let newFileName = fileName.contains(".html") ? fileName : fileName + ".html"
        
        if accept.count >= "text".count && accept.contains("text/html") {
            // html 拦截
            print("html = \(String(describing: requestUrlString))")
            loadLocalFile(fileName: creatCacheKey(urlSchemeTask: urlSchemeTask), urlSchemeTask: urlSchemeTask)
        } else if isJSOrCSSFile(requestUrlString) {
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
    
    func isJSOrCSSFile(_ fileName: String?) -> Bool {
        guard let fileName = fileName, fileName.count > 0 else { return false }
        let pattern = "\\.(js|css)"
        do {
        let result = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive).matches(in: fileName, options: NSRegularExpression.MatchingOptions.init(rawValue: 0), range: NSRange(location: 0, length: fileName.count))
        
        return result.count > 0
        } catch {
            return false
        }
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
            let dask = session.dataTask(with: request) { (data, response, error) in
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
            
            dask.resume()
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
    
    
    func resendRequset(urlSchemeTask: WKURLSchemeTask, mineType: String?, requestData: Data) {
        guard let url = urlSchemeTask.request.url else { return }
        let mineT = mineType ?? "text/html"
        let response = URLResponse(url: url, mimeType: mineT, expectedContentLength: requestData.count, textEncodingName: nil)
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(requestData)
        urlSchemeTask.didFinish()
    }
}

class WebViewVC: UIViewController {
    
    var urlString: String
    var timer: DispatchSourceTimer?
    
    var lastTime: Double?
    
    lazy var webview: WKWebView = {
        let configration = WKWebViewConfiguration.init()
        configration.setURLSchemeHandler(CustomRLSchemeHandler(), forURLScheme: "customscheme")
        let wkwebView = WKWebView(frame: CGRect.zero, configuration: configration)
        wkwebView.navigationDelegate = self
        wkwebView.uiDelegate = self
        
//        let wkwebView = HPKPageManager.sharedInstance().dequeueWebView(with: HPKWebView.self, webViewHolder: self)
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

extension WebViewVC: WKUIDelegate {
    
    
    
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

