//
//  ViewController.swift
//  NYOpenH5Demo
//
//  Created by 陈良静 on 2019/7/24.
//  Copyright © 2019 陈良静. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    let datasoures = ["https://juejin.im/post/5d8da122f265da5b5a7209fa", "https://github.com/ljchen1129/SecondsOpenH5", "https://chenliangjing.me/2019/09/27/iOS-%E7%AB%AF-h5-%E9%A1%B5%E9%9D%A2%E7%A7%92%E5%BC%80%E4%BC%98%E5%8C%96%E5%AE%9E%E8%B7%B5/", "https://www.zhihu.com", "https://www.douban.com/", "https://www.taobao.com", "https://www.jd.com/", "https://www.apple.com/"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 添加磁盘容量大小
        var total: UInt = 0
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last else { return  }
        let fileCacheDir = cacheDir.appendingPathComponent("H5ResourceCache")
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: fileCacheDir.path)
            for file in files {
                let fileUrl = fileCacheDir.appendingPathComponent(file)
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileUrl.path) {
                    total += (attributes[FileAttributeKey.size] as? UInt) ?? 0
                }
            }
        } catch {
            
        }
        
        let cacheSize = String(format: "%.2f", Double(total)/1024/1024)
        navigationItem.title = "磁盘总缓存大小：\(cacheSize)MB"
    }
}

extension ViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datasoures.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        if let cell = tableView.dequeueReusableCell(withIdentifier: "cellID") {
            cell.textLabel?.text = datasoures[indexPath.row]
            return cell
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: "cellID")
            cell?.textLabel?.text = datasoures[indexPath.row]
            return cell!
        }
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let index = indexPath.row
        let urlString = datasoures[index]
        let vc = WebViewVC(urlString: urlString)
        navigationController?.pushViewController(vc, animated: true)
    }
}

