//
//  MemeryCache.swift
//  OpenH5Demo
//
//  Created by 陈良静 on 2019/7/29.
//  Copyright © 2019 陈良静. All rights reserved.
//

import Foundation

/*
 使用双链表（逻辑） + hashMap（存储） 实现 LRU 缓存淘汰。三个维度：缓存时长、缓存数量、缓存大小。增删改查都是 O(1) 时间复杂度
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
/// 链表节点
class LinkedNode: NSObject {
    /// 链表前驱节点
    var prev: LinkedNode?
    /// 链表后继节点
    var next: LinkedNode?
    
    var key: AnyHashable!
    var value: Any!
    var cost: UInt!
    var time: TimeInterval!
}

/// 链表对象
class LinkedNodeMap: NSObject {
    /// 实现链表的存储结构
    var dict = [AnyHashable: LinkedNode]()
    
    /// 链表节点总占得空间大小
    var totalCost: UInt = 0
    /// 链表节点的数量
    var totalCount: UInt = 0
    
    /// 头结点
    var head: LinkedNode?
    
    /// 为节点
    var tail: LinkedNode?
    
    /// 在头节点位置插入节点
    ///
    /// - Parameter node:
    func insertNodeAtHead(_ node: LinkedNode) {
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
    func bringNodeToHead(_ node: LinkedNode) {
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
    func removeNode(_ node: LinkedNode) {
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
class MemoryCache: NSObject, Cacheable {
    ///////////////////////////////////  public  //////////////////////////////////////////
    public static let shared = MemoryCache()
    
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
    private var linedMap: LinkedNodeMap
    /// 串行队列
    private var queue: DispatchQueue
    private var lock: pthread_mutex_t
    
    // MARK: - lifeCycle
    override init() {
        lock = pthread_mutex_t.init()
        linedMap = LinkedNodeMap.init()
        queue = DispatchQueue(label: String(describing: type(of: MemoryCache.self)))
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
}

// MARK: - Acccess 公共访问接口
extension MemoryCache {

    public func contain(forKey key: AnyHashable) -> Bool {
        pthread_mutex_lock(&lock)
        let contains = linedMap.dict.contains(where: {$0.key == key})
        pthread_mutex_unlock(&lock)
        
        return contains
    }

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

    public func setObject(_ object: Any, forKey key: AnyHashable, withCost cost: UInt) {
        pthread_mutex_lock(&lock)
        let now = CACurrentMediaTime()
        guard let node = linedMap.dict[key] else {
            // 节点不存在，新建一个。插入到链表的头部
            let node = LinkedNode.init()
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
        
        pthread_mutex_unlock(&lock)
    }
    
    public func removeObject(forKey key: AnyHashable) {
        pthread_mutex_lock(&lock)
        guard let node = linedMap.dict[key] else {
            pthread_mutex_lock(&lock)
            return
        }
        
        linedMap.removeNode(node)
        pthread_mutex_unlock(&lock)
    }
    
    public func removeAllObject() {
        pthread_mutex_lock(&lock)
        linedMap.removeAll()
        pthread_mutex_unlock(&lock)
    }
}

// MARK: - trim 将缓存大小移除到规定大小
extension MemoryCache {
    public func trim(withCost cost: UInt) {
        var finish = false
        pthread_mutex_lock(&lock)
        if (costLimit == 0) {
            linedMap.removeAll()
            finish = true
        } else if (linedMap.totalCost <= cost) {
            finish = true
        }
        
        pthread_mutex_unlock(&lock)
        if (finish) { return }
        
        while (finish == false) {
            if (pthread_mutex_trylock(&lock) == 0) {
                if (linedMap.totalCost > cost) {
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
        } else if (linedMap.totalCount <= count) {
            finish = true
        }
        pthread_mutex_unlock(&lock)
        if (finish) { return }
        
        // 从尾节点开始向前删除节点，直到满足缓存策略
        while (finish == false) {
            if (pthread_mutex_trylock(&lock) == 0) {
                if (linedMap.totalCount > count) {
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
    
    public func trim(withAge age: TimeInterval) {
        var finish = false
        let now = CACurrentMediaTime()
        pthread_mutex_lock(&lock)
        if (ageLimit <= 0) {
            linedMap.removeAll()
            finish = true
        } else if (linedMap.tail == nil || (now - linedMap.tail!.time) <= age) {
            finish = true
        }
        pthread_mutex_unlock(&lock)
        if (finish) { return }
        
        while (finish == false) {
            if (pthread_mutex_trylock(&lock) == 0) {
                if ((linedMap.tail != nil) && (now - linedMap.tail!.time) > age) {
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
