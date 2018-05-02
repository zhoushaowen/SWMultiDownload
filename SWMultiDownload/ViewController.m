//
//  ViewController.m
//  SWMultiDownload
//
//  Created by zhoushaowen on 2017/3/6.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import "ViewController.h"
#import "SWTableViewCell.h"
#import "SWMultiDownloadManager.h"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
{
    UITableView *_tableView;
    NSArray *_array;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _array = @[@"http://download.netbeans.org/netbeans/8.2/final/bundles/netbeans-8.2-macosx.dmg",
               @"http://sc1.111ttt.com/2016/1/06/25/199251943186.mp3",
               @"https://codeload.github.com/gyjzh/LLWeChat/zip/master",
               @"http://dldir1.qq.com/qqfile/QQforMac/QQ_V6.4.0.dmg",
               ];
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.tableFooterView = [UIView new];
    [self.view addSubview:_tableView];
    [_tableView registerNib:[UINib nibWithNibName:@"SWTableViewCell" bundle:nil] forCellReuseIdentifier:@"cell"];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _array.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SWTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    [cell.downloadBtn addTarget:self action:@selector(downloadBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    cell.downloadBtn.tag = indexPath.row;
    return cell;
}

- (void)downloadBtnClick:(UIButton *)sender
{
    NSString *url = _array[sender.tag];
    NSString *name = [url lastPathComponent];
    [[SWMultiDownloadManager sharedInstance] downloadBigFileWithUrl:url toPath:[@"/Users/zhoushaowen/Desktop/" stringByAppendingPathComponent:name] progress:^(unsigned long long receivedSize, unsigned long long expectedSize, NSURL *targetURL) {
        SWTableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:sender.tag inSection:0]];
        [cell.progressView setProgress:receivedSize*1.0/expectedSize animated:YES];
    } completed:^(NSError *error, NSString *dataPath, BOOL finished) {
        
    }];
}










@end
