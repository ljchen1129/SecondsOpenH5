//
//  NYH5SecondOpenUtil.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/8/2.
//  Copyright © 2019 陈良静. All rights reserved.
//

import Foundation
import CoreServices
import CommonCrypto

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
    
    //根据后缀获取对应的Mime-Type
    static func mimeType(pathExtension: String?) -> String {
        guard let pathExtension = pathExtension else { return "application/octet-stream" }
        
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
}


