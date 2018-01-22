//
//  WYAVManager.h
//  RecordVideoAndTakePhoto
//
//  Created by lwy1218 on 2017/8/29.
//  Copyright © 2017年 lwy1218. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


@interface WYAVManager : NSObject

/** 光标的大小 默认{50,50} */
@property (nonatomic , assign) CGSize cursorIconSize;

/// 是否显示光标 默认为NO
@property (nonatomic , assign) BOOL showCursor;

/* 媒体捕捉会话 */
@property (nonatomic , strong, readonly) AVCaptureSession *session;
/** 预览图层 */
@property (nonatomic , strong, readonly) AVCaptureVideoPreviewLayer *previewLayer;
/** 光标 */
@property (nonatomic , strong, readonly) UIImageView *cursorIconView;

/**
 开始录制
 */
@property (nonatomic , copy) void(^didStartRecordingVideo) (AVCaptureFileOutput *captureOutput, NSURL *fileURL, NSArray *connections);


/**
 结束录制
 */
@property (nonatomic , copy) void(^didFinishRecordingVideo) (AVCaptureFileOutput *captureOutput, NSURL *fileURL, NSArray *connections, NSError *error);

- (instancetype)initWithPreview:(UIView *)preview;

/// 开始运行
- (void)startRunning;
/// 结束运行
- (void)stopRunning;

/// 设置闪光灯模式
- (void)setFlashMode:(AVCaptureFlashMode)mode;

/// 拍照
- (void)takePhoto:(void(^)(UIImage * image))callBack;
/// 切换摄像头
- (void)switchCamera;

/** 开始录制视频 */
- (void)startRecordingVideoToFileURL:(NSURL *)outputFileURL;

/** 结束录制视频 */
- (void)stopRecordingVideo;


@end

