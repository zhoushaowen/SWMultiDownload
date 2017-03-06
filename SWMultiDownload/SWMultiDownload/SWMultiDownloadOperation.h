//
//  SWMultiDownloadOperation.h
//  多线程下载大文件
//
//  Created by 周少文 on 2017/1/26.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWSingleDownloader.h"

@interface SWMultiDownloadOperation : NSOperation

@property (nonatomic,copy,readonly) NSString *url;
/** 文件保存的地址 */
@property (nonatomic,copy,readonly) NSString *filePath;
@property (nonatomic,readonly) BOOL isDownloading;
@property (nonatomic,readonly) BOOL isFileExists;//文件是否以存在
@property (nonatomic,readonly) CGFloat progress;

- (void)startDownloadingWithUrl:(NSString *)url toPath:(NSString *)filePath progress:(void(^)(CGFloat progress))progressBlock completed:(void(^)(NSError *error))completedBlock;

@end
