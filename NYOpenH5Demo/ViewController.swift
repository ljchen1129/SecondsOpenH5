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
    
    let datasoures = ["customscheme://www.imeos.one/", "customscheme://www.omniexplorer.info/", "customscheme://etherscan.io/", "customscheme://eostracker.io/", "customscheme://m.btc.com", "customscheme://neotracker.io/"]
    
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
        
//        let vc = AppHostViewController.init()
//        vc.url = "https://www.imeos.one/"
//        vc.pageTitle = "xxxx"
//        navigationController?.pushViewController(vc, animated: true)
    }
}
