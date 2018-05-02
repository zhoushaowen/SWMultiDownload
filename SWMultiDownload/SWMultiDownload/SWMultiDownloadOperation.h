//
//  SWMultiDownloadOperation.h
//  多线程下载大文件
//
//  Created by 周少文 on 2017/1/26.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWSingleDownloader.h"

typedef void(^SWMultiDownloadProgressBlock)(unsigned long long receivedSize,unsigned long long expectedSize,NSURL *targetURL);
typedef void(^SWMultiDownloadCompletedBlock)(NSError *error,NSString *dataPath,BOOL finished);


@interface SWMultiDownloadOperation : NSOperation

/**
 文件资源地址
 */
@property (nonatomic,copy) NSString *url;

/**
 文件保存在本地的地址
 */
@property (nonatomic,copy) NSString *filePath;
@property (nonatomic,strong) SWMultiDownloadProgressBlock progressBlock;
@property (nonatomic,strong) SWMultiDownloadCompletedBlock completedBlock;

- (void)cancelDownloading;

@end
