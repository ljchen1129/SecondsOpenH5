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
    
    let datasoures = ["https://juejin.im/", "https://www.jianshu.com/", "https://www.sina.com.cn/", "https://github.com/", "https://stackoverflow.com/", "https://baidu.com", "https://sohu.com", "https://zhihu.com", "https://chenliangjing.me"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
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

