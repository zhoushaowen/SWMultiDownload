//
//  SWSingleDownloader.m
//  多线程下载大文件
//
//  Created by 周少文 on 2017/1/26.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import "SWSingleDownloader.h"

@interface SWSingleDownloader ()<NSURLSessionDataDelegate>

/** 文件句柄 */
@property (nonatomic,strong) NSFileHandle *fileHandle;
@property (nonatomic,strong) NSURLSessionDataTask *dataTask;
@property (nonatomic,strong) NSURLSession *session;
@property (nonatomic) BOOL isBeginReceiveData;//是否已经开始接收数据


@end

@implementation SWSingleDownloader

/*
 HTTP的Range头信息
 通过设置请求头Range可以指定每次从网路下载数据包的大小
 Range示例
 bytes=0-499 从0到499的头500个字节
 bytes=500-999 从500到999的第二个500字节
 bytes=500- 从500字节以后的所有字节
 
 bytes=-500 最后500个字节
 bytes=500-599,800-899 同时指定几个范围
 Range小结
 - 用于分隔
 前面的数字表示起始字节数
 后面的数组表示截止字节数，没有表示到末尾
 , 用于分组，可以一次指定多个Range，不过很少用
 */

- (NSFileHandle *)fileHandle {
    if(!_fileHandle){
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:_filePath];
    }
    return _fileHandle;
}

- (void)startDownloading {
    if(_isDownloading) return;
    if(_dataTask){
        [_dataTask cancel];
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:_filePath]){
        [fileManager createFileAtPath:_filePath contents:nil attributes:nil];
    }else{
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:_filePath error:nil];
        _currentLength = [attributes[NSFileSize] unsignedLongLongValue];
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_url?:@""]];
    request.timeoutInterval = 30.0f;
    [request addValue:[NSString stringWithFormat:@"bytes=%lld-%lld",_begin+_currentLength,_end] forHTTPHeaderField:@"Range"];
    NSURLSessionConfiguration *configuration  =[NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    _dataTask = [self.session dataTaskWithRequest:request];
    [_dataTask resume];
    _isDownloading = YES;
}

- (void)cancelDownloading {
    [_dataTask cancel];
    //NSURLSession的delegate是strong,取消会话,解决循环引用,释放内存.
    [self.session invalidateAndCancel];
    self.session = nil;
    _isDownloading = NO;
    [self.fileHandle closeFile];
    self.fileHandle = nil;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    _totalLength = response.expectedContentLength + _currentLength;
//    NSLog(@"总的下载量:%llu+++++++%llu++++++++%lld",self.totalLength,_currentLength,_end -_begin + 1);
    [self.fileHandle seekToEndOfFile];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    @try {
        [self.fileHandle writeData:data];
    } @catch (NSException *exception) {
        
    } @finally {
        
    }
    _currentLength += data.length;
    CGFloat progress = _currentLength*1.0/_totalLength;
    [self setValue:@(progress) forKey:@"progress"];
    if(_progressCallback){
        _progressCallback(progress);
    }
    if(self.beginReceiveDataCallback && !_isBeginReceiveData){
        self.beginReceiveDataCallback();
    }
    _isBeginReceiveData = YES;
}

#pragma mark - NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if(error.code == NSURLErrorCancelled) return;
    if(error){
        NSLog(@"下载错误:%@",error);
        _error = error;
        [self.session invalidateAndCancel];
    }else{
        [self.session finishTasksAndInvalidate];
    }
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    if(_finishDownload){
        _finishDownload(error);
    }
    _isDownloading = NO;
    _isBeginReceiveData = NO;
    self.session = nil;
}

- (void)dealloc
{
    NSLog(@"%s",__func__);
}


@end
