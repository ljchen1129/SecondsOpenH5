//
//  NYCacheable.swift
//  NiuYan
//
//  Created by 陈良静 on 2019/8/7.
//  Copyright © 2019 niuyan.com. All rights reserved.
//

import Foundation

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
