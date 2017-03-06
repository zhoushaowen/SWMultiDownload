//
//  ViewController.m
//  SWMultiDownload
//
//  Created by zhoushaowen on 2017/3/6.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import "ViewController.h"
#import "SWTableViewCell.h"
#import "SWMultiDownloadOperation.h"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
{
    UITableView *_tableView;
    NSArray *_array;
}

@property (nonatomic,strong) NSMutableArray *downloaders;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _array = @[@"http://download.netbeans.org/netbeans/8.2/final/bundles/netbeans-8.2-macosx.dmg",@"http://sc1.111ttt.com/2016/1/06/25/199251943186.mp3"];
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.tableFooterView = [UIView new];
    [self.view addSubview:_tableView];
    [_tableView registerNib:[UINib nibWithNibName:@"SWTableViewCell" bundle:nil] forCellReuseIdentifier:@"cell"];
    [_array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        SWMultiDownloadOperation *download = [[SWMultiDownloadOperation alloc] init];
        [self.downloaders addObject:download];
    }];
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
    [self.downloaders[sender.tag] startDownloadingWithUrl:url toPath:[@"/Users/zhoushaowen/Desktop/" stringByAppendingPathComponent:name] progress:^(CGFloat progress) {
        SWTableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:sender.tag inSection:0]];
        [cell.progressView setProgress:progress animated:YES];
    } completed:^(NSError *error) {
        
    }];
}

- (NSMutableArray *)downloaders
{
    if(!_downloaders){
        _downloaders = [NSMutableArray arrayWithCapacity:0];
    }
    return _downloaders;
}










@end
