//
//  SWSingleDownloader.h
//  多线程下载大文件
//
//  Created by 周少文 on 2017/1/26.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGBase.h>

@interface SWSingleDownloader : NSObject

@property (nonatomic) long long begin;
@property (nonatomic) long long end;
@property (nonatomic,copy) NSString *filePath;
@property (nonatomic,copy) NSString *url;
/** 当前下载量 */
@property (nonatomic,readonly) unsigned long long currentLength;
/** 总的文件大小 */
@property (nonatomic,readonly) unsigned long long totalLength;
@property (nonatomic,readonly) CGFloat progress;
@property (nonatomic,strong,readonly) NSError *error;
@property (nonatomic,readonly) BOOL isDownloading;
@property (nonatomic,strong) void(^progressCallback)(CGFloat progress);
@property (nonatomic,strong) void(^beginReceiveDataCallback)();
@property (nonatomic,strong) void(^finishDownload)(NSError *error);

- (void)startDownloading;
- (void)cancelDownloading;

@end
