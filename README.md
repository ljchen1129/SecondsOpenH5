### 前言

最近公司项目中需要做秒开 h5 页面的优化需求，于是调研了下市面上的方案，并结合本公司具体的业务需求做了一次这方面的优化实践，这篇文章是对这次优化实践的记录，文末附上源代码下载。

### 先看效果

![ezgif.com-optimize](http://liangjinggege.com/2019-09-27-074217.gif)

### 优化思路

首先来看，在 iOS 平台加载一个 H5 网页，需要经过哪些步骤：

初始化 webview -> 请求页面 -> 下载数据 -> 解析HTML -> 请求 js/css 资源 -> dom 渲染 -> 解析 JS 执行 -> JS 请求数据 -> 解析渲染 -> 下载渲染图片

![WebViewå¯å¨æ¶é´](http://liangjinggege.com/2019-09-27-44204.png)

由于在 dom 渲染前的用户看到的页面都是白屏，优化思路具体也是去分析在 dom 渲染前每个步骤的耗时，去优化性价比最高的部分。这里面又可以分为前端能做的优化，以及客户端能做的优化，前端这个需要前端那边配合，暂且不在这篇文章中讨论，这边文章主要讨论的是客户端能做的优化思路。总体思路大概也是这样：

1. 能够缓存的就尽量缓存，用空间换时间。这里可以去拦截的 h5 页面的所有资源请求，包括 html、css/js，图片、数据等，右客户端来接管资源的缓存策略（包括缓存的最大空间占用，缓存的淘汰算法、缓存过期等策略）；
2. 能够预加载的，就提前预加载。可以预先处理一些耗时的操作，如在 App 启动的时候就提前初始化好 webview 等待使用；
3. 能够并行的的，就并行进行，利用设备的多核能力。如在加载 webview 的时候就可以同时去加载需要的资源；

#### 初始化 webview 阶段

在客户端加载一个 网页和在 PC 上加载一个网页不太一样，在 PC 上，直接在浏览器中输入一个 url 就开始建立连接了，而在客户端上需要先`启动浏览器内核`，初始化一些 webview 的`全局服务和资源`，再开始`建立连接`，可以看一下[美团](https://tech.meituan.com/2017/06/09/webviewperf.html)测试的这个阶段的耗时大概是多少：

![image-20190927112358207](http://liangjinggege.com/2019-09-27-044203.png)

在客户端第一次打开 h5 页面，会有一个 webview 初始化的耗时，

可以看到数据在使用 WKWebView 的情况下，首次初始化的时间耗时有 760 多毫秒，所以如果能够在打开网页的时候使用已经初始化好了的 webview 来加载，那么这部分的耗时就没有了。

这边实现了一个 webview 缓冲池的方案，在 App 启动的时候就初始化了，在需要打开网页的时候直接从缓冲池里面去取 webview 就行：

```swift
+ (void)load
{
    [WebViewReusePool swiftyLoad];
}

@objc public static func swiftyLoad() {
    NotificationCenter.default.addObserver(self, selector: #selector(didFinishLaunchingNotification), name: UIApplication.didFinishLaunchingNotification, object: nil)
}

@objc static func didFinishLaunchingNotification() {
    // 预先初始化webview
    WebViewReusePool.shared.prepareWebView()
}

func prepareWebView() {
    DispatchQueue.main.async {
        let webView = ReuseWebView(frame: CGRect.zero, configuration: self.defaultConfigeration)
        self.reusableWebViewSet.insert(webView)
    }
}
```



#### 建立连接 -> dom 渲染前阶段

##### #拦截请求

在 iOS 11 及其以上系统上可以 WKWebView 提供的 `setURLSchemeHandler` 方法添加自定义的 Scheme，相比较NSURLProtocol 私有 api 的方案没有审核风险，然后就可以在 WKURLSchemeHandler 协议里面拦截所有的自定义请求了：

```swift
// 自定义拦截请求开始
func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    let headers = urlSchemeTask.request.allHTTPHeaderFields
    guard let accept = headers?["Accept"] else { return }
    guard let requestUrlString = urlSchemeTask.request.url?.absoluteString else { return }

    if accept.count >= "text".count && accept.contains("text/html") {
        // html 拦截
        print("html = \(String(describing: requestUrlString))")
        // 加载本地的缓存资源
        loadLocalFile(fileName: creatCacheKey(urlSchemeTask: urlSchemeTask), urlSchemeTask: urlSchemeTask)
    } else if (requestUrlString.isJSOrCSSFile()) {
        // js || css 文件
        print("js || css = \(String(describing: requestUrlString))")
        loadLocalFile(fileName: creatCacheKey(urlSchemeTask: urlSchemeTask), urlSchemeTask: urlSchemeTask)

    } else if accept.count >= "image".count && accept.contains("image") {
        // 图片
        print("image = \(String(describing: requestUrlString))")
        guard let originUrlString = urlSchemeTask.request.url?.absoluteString.replacingOccurrences(of: "customscheme", with: "https") else { return }
				
      	// 图片可以使用 SDWebImageManager 提供的缓存策略
        SDWebImageManager.shared.loadImage(with: URL(string: originUrlString), options: SDWebImageOptions.retryFailed, progress: nil) { (image, data, error, type, _, _) in
            if let image = image {
                guard let imageData = image.jpegData(compressionQuality: 1) else { return }
              	
                // 资源不存在就重新发送请求
                self.resendRequset(urlSchemeTask: urlSchemeTask, mineType: "image/jpeg", requestData: imageData)
            } else {
                self.loadLocalFile(fileName: self.creatCacheKey(urlSchemeTask: urlSchemeTask), urlSchemeTask: urlSchemeTask)
            }
        }

    } else {
        // other resources
        print("other resources = \(String(describing: requestUrlString))")
        guard let cacheKey = self.creatCacheKey(urlSchemeTask: urlSchemeTask) else { return }
        requestRomote(fileName: cacheKey, urlSchemeTask: urlSchemeTask)
    }
}

/// 自定义请求结束时调用
func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
	
}
```

##### #实现资源缓存

这里使用 swift 实现了内存和磁盘两种缓存逻辑，主要参(chao)考(xi)了 [YYCache](https://github.com/ibireme/YYCache) 的思路和源码，内存缓存利用`双链表（逻辑） + hashMap（存储）` 实现` LRU`缓存淘汰算法 ，增删改查都是 O(1) 时间复杂度，磁盘缓存使用了沙盒文件存储。两种缓存都实现了缓存时长、缓存数量、缓存大小三个维度的缓存管理。

使用协议的方式定义了接口 API：

```swift
protocol Cacheable {
    associatedtype ObjectType
    
    /// 缓存总数量
    var totalCount: UInt { get }
    /// 缓存总大小
    var totalCost: UInt { get }
    
    ///  缓存是否存在
    ///
    /// - Parameter key: 缓存key
    /// - Returns: 结果
    func contain(forKey key: AnyHashable) -> Bool
    
    /// 返回指定key的缓存
    ///
    /// - Parameter key:
    /// - Returns:
    func object(forKey key: AnyHashable) -> ObjectType?
    
    /// 设置缓存 k、v
    ///
    /// - Parameters:
    ///   - object:
    ///   - key:
    func setObject(_ object: ObjectType, forKey key: AnyHashable)
    
    /// 设置缓存 k、v、c
    ///
    /// - Parameters:
    ///   - object:
    ///   - key:
    ///   - cost:
    func setObject(_ object: ObjectType, forKey key: AnyHashable, withCost cost: UInt)
    
    /// 删除指定key的缓存
    ///
    /// - Parameter key:
    func removeObject(forKey key: AnyHashable)
    
    /// 删除所有缓存
    func removeAllObject()
    
    /// 根据缓存大小清理
    ///
    /// - Parameter cost: 缓存大小
    func trim(withCost cost: UInt)
    
    /// 根据缓存数量清理
    ///
    /// - Parameter count: 缓存数量
    func trim(withCount count: UInt)
    
    /// 根据缓存时长清理
    ///
    /// - Parameter age: 缓存时长
    func trim(withAge age: TimeInterval)
}

extension Cacheable {
    func setObject(_ object: ObjectType, forKey key: AnyHashable) {
        setObject(object, forKey: key, withCost: 0)
    }
}
```

##### 用法：

```swift
/// h5 页面资源缓存
class H5ResourceCache: NSObject {
    /// 内存缓存大小：10M
    private let kMemoryCacheCostLimit: UInt = 10 * 1024 * 1024
    /// 磁盘文件缓存大小： 10M
    private let kDiskCacheCostLimit: UInt = 10 * 1024 * 1024
    /// 磁盘文件缓存时长：30 分钟
    private let kDiskCacheAgeLimit: TimeInterval = 30 * 60
    
    private var memoryCache: MemoryCache
    private var diskCache: DiskFileCache
    
    override init() {
        memoryCache = MemoryCache.shared
        memoryCache.costLimit = kMemoryCacheCostLimit
            
        diskCache = DiskFileCache(cacheDirectoryName: "H5ResourceCache")
        diskCache.costLimit = kDiskCacheCostLimit
        diskCache.ageLimit = kDiskCacheAgeLimit
        
        super.init()
    }
    
    func contain(forKey key: String) -> Bool {
        return memoryCache.contain(forKey: key) || diskCache.contain(forKey: key)
    }
    
    func setData(data: Data, forKey key: String) {
        guard let dataString = String(data: data, encoding: .utf8) else { return }
        memoryCache.setObject(dataString.data(using: .utf8) as Any, forKey: key, withCost: UInt(data.count))
        diskCache.setObject(dataString.data(using: .utf8)!, forKey: key, withCost: UInt(data.count))
    }
    
    func data(forKey key: String) -> Data? {
        if let data = memoryCache.object(forKey: key) {
            print("这是内存缓存")
            return data as? Data
        } else {
            guard let data = diskCache.object(forKey: key) else { return nil}
            memoryCache.setObject(data, forKey: key, withCost: UInt(data.count))
            print("这是磁盘缓存")
            return data
        }
    }
    
    func removeData(forKey key: String) {
        memoryCache.removeObject(forKey: key)
        diskCache.removeObject(forKey: key)
    }
    
    func removeAll() {
        memoryCache.removeAllObject()
        diskCache.removeAllObject()
    }
}
```

### 效果

![image-20190927122508611](http://liangjinggege.com/2019-09-27-044205.png)

### 注意事项

#### #1. WKURLSchemeHandler 对象实例被释放后，网络加载回调依然访问了，这个时候就会出现崩溃`The task has already been stopped`的错误

![image-20190926190443221](http://liangjinggege.com/2019-09-27-044204.png)

![image-20190926190652788](http://liangjinggege.com/2019-09-27-044206.png)

##### 解决方案：用一个字典持有 WKURLSchemeTask 实例的状态，分别在拦截请求开始的地方和拦截请求结束的地方分别记录

```swift
// MARK:- 请求拦截开始
func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    holdUrlSchemeTasks[urlSchemeTask.description] = true
}

/// 自定义请求结束时调用
func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    holdUrlSchemeTasks[urlSchemeTask.description] = false
}

// 需要用到的 urlSchemeTask 实例的地方，加一层判断
// urlSchemeTask 是否提前结束，结束了调用实例方法会崩溃
if let isValid = self.holdUrlSchemeTasks[urlSchemeTask.description] {
    if !isValid {
        return
    }
}
```

#### #2. 网页乱码

添加网络请求响应接收格式：

```swift
 manager.responseSerializer.acceptableContentTypes = Set(arrayLiteral: "text/html", "application/json", "text/json", "text/javascript", "text/plain", "application/javascript", "text/css", "image/svg+xml", "application/font-woff2", "application/octet-stream")
```

#### #3. WKWebView 白屏

```swift
// 白屏
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if webview.title == nil {
        webview.reload()
    }
}

// 白屏
func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    webView.reload()
}
```



### 源代码

[https://github.com/ljchen1129/SecondsOpenH5](https://github.com/ljchen1129/SecondsOpenH5)



### TODOList

1. 撰写单元测试
2. 去除第三方库 SDWebImage  和 AFNetworking，使用原生实现
3. 资源预加载逻辑
4. 统一的异常管理
5. 更加 Swift style



### 参考资料

1. https://blog.cnbang.net/tech/3477/
2. https://mp.weixin.qq.com/s/0OR4HJQSDq7nEFUAaX1x5A
3. https://juejin.im/post/5c9c664ff265da611624764d
4. https://tech.meituan.com/2017/06/09/webviewperf.html



------

分享个人技术学习记录和跑步马拉松训练比赛、读书笔记等内容，感兴趣的朋友可以关注我的公众号「青争哥哥」。

![青争哥哥](http://liangjinggege.com/qrcode_for_gh_0be790c1f754_258.jpg)