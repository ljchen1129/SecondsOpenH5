//
//  NYMemeryCache.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/7/29.
//  Copyright © 2019 陈良静. All rights reserved.
//

import Foundation

/// 链表节点
class NYLinkedNode: NSObject {
    /// 链表前驱节点
    var prev: NYLinkedNode?
    /// 链表后继节点
    var next: NYLinkedNode?
    
    var key: AnyHashable!
    var value: Any!
    var cost: UInt!
    var time: TimeInterval!
}

/*
 使用双链表 + hashMap 实现 LRU 缓存淘汰。三个维度：缓存时长、缓存数量、缓存大小。增删改查都是 O(1) 时间复杂度
 1. 缓存新增：
     1. 缓存未满，将新的缓存节点插入到链表的头结点位置。
     2. 缓存已满，删除尾节点，将新缓存节点插入到头结点位置。
 2. 缓存删除：
    1. 根据缓存时长、缓存数量、缓存大小三个维度，从尾节点向前删除缓存
 3. 缓存查询：
    1. 缓存命中，将命中的缓存节点移动到头结点位置
 4. 缓存修改：
    1. 更新节点。
    2. 将节点移动到链表头部
 */
/// 链表对象
class NYLinkedNodeMap: NSObject {
    /// 实现链表的存储
    var dict = [AnyHashable: NYLinkedNode]()
    
    /// 链表节点总占得空间大小
    var totalCost: UInt = 0
    /// 链表节点的数量
    var totalCount: UInt = 0
    
    /// 头结点
    var head: NYLinkedNode?
    
    /// 为节点
    var tail: NYLinkedNode?
    
    /// 在头节点位置插入节点
    ///
    /// - Parameter node:
    func insertNodeAtHead(_ node: NYLinkedNode) {
        dict[node.key] = node
        totalCost += node.cost
        totalCount += 1
        if let _ = head  {
            node.next = head
            head?.prev = node
            head = node
        } else {
            head = node
            tail = node
        }
    }
    
    /// 将节点移动到头节点位置
    ///
    /// - Parameter node:
    func bringNodeToHead(_ node: NYLinkedNode) {
        if head == node { return }
        
        if (tail == node) {
            tail = node.prev
            tail?.next = nil
        } else {
            node.next?.prev = node.prev
            node.prev?.next = node.next
        }
        
        node.next = head
        node.prev = nil
        head?.prev = node
        head = node
    }
    
    /// 删除指定节点
    ///
    /// - Parameter node:
    func removeNode(_ node: NYLinkedNode) {
        dict.removeValue(forKey: node.key)
       
        totalCost -= node.cost
        totalCount -= 1
        if (node.next != nil) { node.next?.prev = node.prev }
        if (node.prev != nil) { node.prev?.next = node.next }
        if head == node { head = node.next }
        if tail == node { tail = node.prev }
    }
    
    /// 删除尾节点
    func removeTailNode() {
        guard let tempTail = tail else { return }
        
        dict.removeValue(forKey: tempTail.key)
        totalCost -= tempTail.cost
        totalCount -= 1
        if (head == tail) {
            head = nil
            tail = nil
        } else {
            tail = tempTail.prev
            tail?.next = nil
        }
    }
    
    /// 清空链表
    func removeAll() {
        totalCost = 0
        totalCount = 0
        head = nil
        tail = nil
        
        if (dict.count > 0) {
            dict.removeAll()
        }
    }
}

/// 内存缓存
class NYMemoryCache: NSObject {
    ///////////////////////////////////  public  //////////////////////////////////////////
    public static let instance = NYMemoryCache()
    
    /// 缓存总数量
    public var totalCount: UInt {
        pthread_mutex_lock(&lock);
        let count = linedMap.totalCount
        pthread_mutex_unlock(&lock)
        
        return count
    }
    /// 缓存总大小
    public var totalCost: UInt {
        pthread_mutex_lock(&lock);
        let cost = linedMap.totalCost
        pthread_mutex_unlock(&lock)
        
        return cost
    }
    
    /// 缓存数量限制
    public var countLimit: UInt
    /// 缓存大小限制
    public var costLimit: UInt
    /// 缓存时长限制
    public var ageLimit: TimeInterval
    
    /// 自动清理缓存时间间隔
    public var autoTrimInterval: TimeInterval
    
    ///////////////////////////////////  private  //////////////////////////////////////////
    /// 双链表对象
    private var linedMap: NYLinkedNodeMap
    /// 串行队列
    private var queue: DispatchQueue
    private var lock: pthread_mutex_t
    
    // MARK: - lifeCycle
    override init() {
        lock = pthread_mutex_t.init()
        linedMap = NYLinkedNodeMap.init()
        queue = DispatchQueue(label: "NYMemoryCahcheQueue")
        costLimit = UInt.max
        countLimit = UInt.max
        ageLimit = Double.greatestFiniteMagnitude
        autoTrimInterval = 5
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarningNotification), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        trimRecursively()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        linedMap.removeAll()
        
        pthread_mutex_destroy(&lock)
    }
    
    // MARK: - notification
    // 收到内存警告
    @objc private func didReceiveMemoryWarningNotification() {
        removeAllObject()
    }
    // 进入后台
    @objc private func didEnterBackgroundNotification() {
        removeAllObject()
    }
    
    // MARK: - privateMethod
    // 定时器递归调用，在后台自动清理超出缓存
    private func trimRecursively() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: DispatchTime.now() + autoTrimInterval) {
            self.trimInBackground()
            self.trimRecursively()
        }
    }
    
    private func trimInBackground() {
        queue.async {
            self.trim(withCount: self.countLimit)
            self.trim(withCost: self.costLimit)
            self.trim(withAge: self.ageLimit)
        }
    }
    
    private func remveObject(forKey key: AnyHashable) {
        pthread_mutex_lock(&lock)
        guard let node = linedMap.dict[key] else {
            pthread_mutex_lock(&lock)
            return
        }
        
        linedMap.removeNode(node)
        pthread_mutex_unlock(&lock)
    }
    
    private func removeAllObject() {
        pthread_mutex_lock(&lock)
        linedMap.removeAll()
        pthread_mutex_unlock(&lock)
    }
}

// MARK: - Acccess 公共访问接口
extension NYMemoryCache {
    ///  缓存是否存在
    ///
    /// - Parameter key: 缓存key
    /// - Returns: 结果
    public func contain(forKey key: AnyHashable) -> Bool {
        pthread_mutex_lock(&lock)
        let contains = linedMap.dict.contains(where: {$0.key == key})
        pthread_mutex_unlock(&lock)
        
        return contains
    }
    
    /// 返回指定key的缓存
    ///
    /// - Parameter key:
    /// - Returns:
    public func object(forKey key: AnyHashable) -> Any? {
        pthread_mutex_lock(&lock)
        guard let node = linedMap.dict[key] else {
            pthread_mutex_unlock(&lock)
            return nil
        }
        
        node.time = CACurrentMediaTime()
        linedMap.bringNodeToHead(node)
        pthread_mutex_unlock(&lock)
        
        return node.value
    }
    
    /// 设置缓存 k、v
    ///
    /// - Parameters:
    ///   - object:
    ///   - key:
    public func setObject(_ object: Any, forKey key: AnyHashable) {
        setObject(object, forKey: key, withCost: 0)
    }
    
    /// 设置缓存 k、v、c
    ///
    /// - Parameters:
    ///   - object:
    ///   - key:
    ///   - cost:
    public func setObject(_ object: Any, forKey key: AnyHashable, withCost cost: UInt) {
        pthread_mutex_lock(&lock);
        let now = CACurrentMediaTime()
        guard let node = linedMap.dict[key] else {
            // 节点不存在，新建一个。插入到链表的头部
            let node = NYLinkedNode.init()
            node.cost = cost
            node.time = now
            node.key = key
            node.value = object
            linedMap.insertNodeAtHead(node)
            pthread_mutex_lock(&lock)
            return
        }
        
        // 节点存在，1.更新节点。2. 将节点移动到链表头部
        linedMap.totalCost -= node.cost;
        linedMap.totalCost += cost
        node.cost = cost
        node.time = now
        node.value = object
        linedMap.bringNodeToHead(node)
        
        // 判断缓存是否满了，缓存数量、缓存大小
        if (linedMap.totalCost > costLimit) {
            queue.async {
                self.trim(withCount: self.costLimit)
            }
        }
        if (linedMap.totalCount > countLimit) {
            linedMap.removeTailNode()
        }
        
        pthread_mutex_unlock(&lock);
    }
}

// MARK: - trim 将缓存大小移除到规定大小
extension NYMemoryCache {
    /// 根据缓存大小清理
    ///
    /// - Parameter cost: 缓存大小
    public func trim(withCost cost: UInt) {
        var finish = false
        pthread_mutex_lock(&lock)
        if (costLimit == 0) {
            linedMap.removeAll()
            finish = true
        } else if (linedMap.totalCost <= costLimit) {
            finish = true
        }
        
        pthread_mutex_unlock(&lock)
        if (finish) { return }
        
        while (finish == false) {
            if (pthread_mutex_trylock(&lock) == 0) {
                if (linedMap.totalCost > costLimit) {
                    linedMap.removeTailNode()
                } else {
                    finish = true
                }
                pthread_mutex_unlock(&lock)
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
    /// 根据缓存数量清理
    ///
    /// - Parameter count: 缓存数量
    public func trim(withCount count: UInt) {
        if (count == 0) {
            removeAllObject()
            return
        }
        
        var finish = false
        pthread_mutex_lock(&lock)
        if (countLimit == 0) {
            linedMap.removeAll()
            finish = true
        } else if (linedMap.totalCount <= countLimit) {
            finish = true
        }
        pthread_mutex_unlock(&lock)
        if (finish) { return }
        
        // 从尾节点开始向前删除节点，直到满足缓存策略
        while (finish == false) {
            if (pthread_mutex_trylock(&lock) == 0) {
                if (linedMap.totalCount > countLimit) {
                    linedMap.removeTailNode()
                } else {
                    finish = true
                }
                pthread_mutex_unlock(&lock)
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
    /// 根据缓存时长清理
    ///
    /// - Parameter age: 缓存时长
    public func trim(withAge age: TimeInterval) {
        var finish = false
        let now = CACurrentMediaTime()
        pthread_mutex_lock(&lock)
        if (ageLimit <= 0) {
            linedMap.removeAll()
            finish = true
        } else if (linedMap.tail == nil || (now - linedMap.tail!.time) <= ageLimit) {
            finish = true
        }
        pthread_mutex_unlock(&lock)
        if (finish) { return }
        
        while (finish == false) {
            if (pthread_mutex_trylock(&lock) == 0) {
                if ((linedMap.tail != nil) && (now - linedMap.tail!.time) > ageLimit) {
                    linedMap.removeTailNode()
                } else {
                    finish = true
                }
                pthread_mutex_unlock(&lock)
            } else {
                usleep(10 * 1000)
            }
        }
    }
}
