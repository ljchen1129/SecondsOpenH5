//
//  ViewController.m
//  oc
//
//  Created by 陈良静 on 2019/7/26.
//  Copyright © 2019 陈良静. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property(nonatomic, strong) NSArray *dataSources;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    self.dataSources = @[@"https://www.imeos.one/", @"https://www.omniexplorer.info/", @"https://etherscan.io/", @"https://eostracker.io/", @"https://m.btc.com", @"https://neotracker.io/"];
    
    self.tableView.tableFooterView = [UIView new];
    
}


#pragma mark UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataSources.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cellID"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cellID"];
    }
    
    cell.textLabel.text = self.dataSources[indexPath.row];
    
    return cell;
}

@end
