//
//  SWMultiDownloadOperation.m
//  多线程下载大文件
//
//  Created by 周少文 on 2017/1/26.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import "SWMultiDownloadOperation.h"
#import "SWMultiDownloadManager.h"
#import <objc/runtime.h>

#define MaxMultilineCount 4

@interface SWMultiDownloadOperation ()
{
    NSURLSessionDataTask *_sessionDataTask;
    dispatch_group_t _group;
}

@property (nonatomic,strong) NSMutableArray<SWSingleDownloader *> *singleDownloaders;
@property (nonatomic,strong) NSError *error;
@property (nonatomic) BOOL isFinishedDownload;
@property (nonatomic,strong) NSFileHandle *fileHandle;
@property (nonatomic,strong) NSString *tmpDownloadPath;//临时下载路径
@property (nonatomic) unsigned long long totalSize;

@end

@implementation SWMultiDownloadOperation

- (void)main
{
    if(self.isCancelled) return;
    _group = dispatch_group_create();
    dispatch_group_enter(_group);
    if([[NSFileManager defaultManager] fileExistsAtPath:_filePath]){
        NSLog(@"文件已存在");
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:nil];
        self.totalSize = [attributes[NSFileSize] unsignedLongLongValue];
        self.isFinishedDownload = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.progressBlock){
                self.progressBlock(self.totalSize, self.totalSize, [NSURL URLWithString:self.url]);
            }
        });
        [self finishDownloading];
        return;
    }
    [self getFileSizeWithCompletion:^(NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if(self.isCancelled) return;
        if(error || response.statusCode != 200){
            self.isFinishedDownload = NO;
            [self finishDownloading];
            return;
        }
        long long fileSize = response.expectedContentLength;
        self.totalSize = fileSize;
        [self createDownloadersWithFileSize:fileSize];
        [self.singleDownloaders makeObjectsPerformSelector:@selector(startDownloading)];
        NSLog(@"多线程下载开始");
    }];
    dispatch_group_wait(_group, DISPATCH_TIME_FOREVER);
    NSLog(@"*******操作执行完毕*********");
}

- (void)cancel
{
    [super cancel];
    [self cancelDownloading];
}

- (NSMutableArray *)singleDownloaders {
    if(!_singleDownloaders){
        _singleDownloaders = [NSMutableArray array];
    }
    return _singleDownloaders;
}

- (NSFileHandle *)fileHandle {
    if(!_fileHandle){
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:_tmpDownloadPath];
    }
    return _fileHandle;
}

- (void)getFileSizeWithCompletion:(void(^)(NSHTTPURLResponse * _Nullable response, NSError * _Nullable error))completedBlock {
    if(_sessionDataTask){
        [_sessionDataTask cancel];
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_url?:@""]];
    request.HTTPMethod = @"HEAD";//从指定的url上获取header内容(类似Get方式)
    request.timeoutInterval = 30.0;
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    NSURLSession *session = [NSURLSession sharedSession];
    _sessionDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"response:%@----error:%@",response,error);
        dispatch_async(dispatch_get_main_queue(), ^{
            if(completedBlock){
                completedBlock((NSHTTPURLResponse *)response,error);
            }
        });
    }];
    [_sessionDataTask resume];
}

- (void)createDownloadersWithFileSize:(long long)fileSize {
    unsigned long long singleFileSize = 0;//每条子线程下载量
    if(fileSize % MaxMultilineCount == 0){
        singleFileSize = fileSize/MaxMultilineCount;
    }else{
        singleFileSize = fileSize/MaxMultilineCount + 1;
    }
    dispatch_group_t group = dispatch_group_create();
    for(int i = 0;i < MaxMultilineCount;i++){
        SWSingleDownloader *downloader = [[SWSingleDownloader alloc] init];
        downloader.url = _url;
        NSString *fileName = [[_filePath stringByDeletingPathExtension] lastPathComponent];
        NSString *filePath = [[_filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"%.2d-%@",i,fileName]];
        downloader.filePath = [filePath stringByAppendingPathExtension:@"tmp"];
        downloader.begin = i*singleFileSize;
        downloader.end = downloader.begin + singleFileSize - 1;
        downloader.progressCallback = ^(unsigned long long currentLength, unsigned long long totalLength) {
            @synchronized (self) {
                //                    NSLog(@"%zd号单线下载器正在下载,下载进度:%f",[self.singleDownloaders indexOfObject:weakDownloader],currentLength*1.0/totalLength);
                __block unsigned long long temp = 0;
                [self.singleDownloaders enumerateObjectsUsingBlock:^(SWSingleDownloader*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    temp += obj.currentLength;
                }];
                CGFloat totalProgress = temp*1.0/self.totalSize;
                NSLog(@"总的下载进度:-----------%f",totalProgress);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(self.progressBlock){
                        self.progressBlock(temp, self.totalSize, [NSURL URLWithString:self.url]);
                    }
                });
            }
        };
        
        dispatch_group_enter(group);
        downloader.finishDownload = ^(NSError *error){
            if(error){
                self.error = error;
                NSLog(@"%d号单线下载失败,原因:%@",i,error.localizedDescription);
            }
            dispatch_group_leave(group);
        };
        [self.singleDownloaders addObject:downloader];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"多线程下载结束");
        if(!self.error){
            [self combineFilesCompleted:^{
                self.isFinishedDownload = YES;
                [self finishDownloading];
            }];
        }else{
            self.isFinishedDownload = NO;
            [self finishDownloading];
        }
    });
    NSFileManager *fileManager = [NSFileManager defaultManager];
    _tmpDownloadPath = [[_filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"totalTmp"];
    if(![fileManager fileExistsAtPath:_tmpDownloadPath]){
        //创建临时文件，文件大小要跟实际大小一致,保证多余的文件的不会重复.
        //1.创建一个0字节文件
        [fileManager createFileAtPath:_tmpDownloadPath contents:nil attributes:nil];
        //2.指定文件大小
        [self.fileHandle truncateFileAtOffset:fileSize];
    }
}

- (void)cancelDownloading {
    [self.singleDownloaders makeObjectsPerformSelector:@selector(cancelDownloading)];
    [self.singleDownloaders removeAllObjects];
    self.progressBlock = nil;
    self.completedBlock = nil;
    if(_group){
        dispatch_group_leave(_group);
    }
}

- (void)finishDownloading {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.completedBlock){
            self.completedBlock(self.error, self.filePath, self.isFinishedDownload);
        }
    });
    [self.singleDownloaders removeAllObjects];
    if(_group){
        dispatch_group_leave(_group);
    }
}

//合并文件
- (void)combineFilesCompleted:(void(^)(void))completed {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *path = [self.filePath stringByDeletingLastPathComponent];
        NSArray *array = [fileManager contentsOfDirectoryAtPath:path error:nil];
        NSString *fileName = [[[self.filePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"tmp"];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH %@",fileName];
        NSArray *filteredArray = [array filteredArrayUsingPredicate:predicate];
        filteredArray = [filteredArray sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:nil ascending:YES]]];
        for(int i=0;i<filteredArray.count;i++){
            NSString *fileName = filteredArray[i];
            NSString *path = [[self.filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:fileName];
            //读取文件片段
            NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
            NSData *data = [handle readDataToEndOfFile];
            unsigned long long offset = self.singleDownloaders[i].begin;
            [self.fileHandle seekToFileOffset:offset];
            [self.fileHandle writeData:data];
            [handle closeFile];
            //删除下载的片段文件
            [fileManager removeItemAtPath:path error:nil];
            NSLog(@"%d合并完成",i);
        }
        NSLog(@"全部合并完成");
        [self.fileHandle closeFile];
        self.fileHandle = nil;
        //移动文件,以达到重命名文件的目的
        [fileManager moveItemAtPath:self.tmpDownloadPath toPath:self.filePath error:nil];
        if(completed){
            dispatch_async(dispatch_get_main_queue(), ^{
                completed();
            });
        }
    });
}

- (void)dealloc
{
    NSLog(@"%s",__func__);
}






@end
