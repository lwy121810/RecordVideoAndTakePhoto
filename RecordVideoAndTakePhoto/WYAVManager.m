//
//  WYAVManager.m
//  RecordVideoAndTakePhoto
//
//  Created by lwy1218 on 2017/8/29.
//  Copyright © 2017年 lwy1218. All rights reserved.
//
/*
 ****************************************************************
 *
 * GitHub: https://github.com/lwy121810
 * 简书地址: http://www.jianshu.com/u/308baa12e8b5
 *  
 ****************************************************************
 */

#import "WYAVManager.h"
#import <AssetsLibrary/AssetsLibrary.h>

#if DEBUG
#define WYLog(FORMAT, ...) do {\
fprintf(stderr,"\nfile:%s \nfunction:%s\nline:%d \ncontent:%s\n", [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String],__FUNCTION__, __LINE__, [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);\
} while (0)
#define debugMethod() WYLog(@"%s", __func__)
#else
#define WYLog(FORMAT, ...) nil
#define debugMethod()
#endif


typedef void (^PropertyChangeBlock) (AVCaptureDevice *device);

@interface WYAVManager ()<AVCaptureFileOutputRecordingDelegate>

/* 媒体捕捉会话 */
@property (nonatomic , strong) AVCaptureSession *session;

/** 数据输入管理对象 相机*/
@property (nonatomic , strong) AVCaptureDeviceInput *cameraDeviceInput;
/** 数据输入管理对象 麦克风 */
@property (nonatomic , strong) AVCaptureDeviceInput *audioDeviceInput;

/** 输出源 图片数据管理对象 */
@property (nonatomic , strong) AVCaptureStillImageOutput *imageOutput;
/** 输出源 视频数据输出管理对象 */
@property (nonatomic , strong) AVCaptureMovieFileOutput *movieFileOutput;

@property (nonatomic , strong) UIView *preview;
/** 预览图层 */
@property (nonatomic , strong) AVCaptureVideoPreviewLayer *previewLayer;
/** 光标 */
@property (nonatomic , strong) UIImageView *cursorIconView;

@property (nonatomic , assign) AVCaptureDevicePosition currentCameraPosition;

@end

@implementation WYAVManager
#pragma mark - lazy load -------
- (UIImageView *)cursorIconView
{
    if (!_cursorIconView) {
        UIImageView *icon = [[UIImageView alloc] init];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.image = [UIImage imageNamed:@"focus"];
        
        [self.preview addSubview:icon];
        CGRect frame = CGRectZero;
        frame.size = _cursorIconSize;
        _cursorIconView = icon;
        _cursorIconView.frame = frame;
    }
    return _cursorIconView;
}
- (AVCaptureMovieFileOutput *)movieFileOutput
{
    if (!_movieFileOutput) {
        _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    }
    return _movieFileOutput;
}
/// 图片输出数据管理对象
- (AVCaptureStillImageOutput *)imageOutput
{
    if (!_imageOutput) {
        AVCaptureStillImageOutput *imageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
        [imageOutput setOutputSettings:outputSettings];//输出设置
        _imageOutput = imageOutput;
    }
    return _imageOutput;
}
- (AVCaptureVideoPreviewLayer *)previewLayer
{
    if (!_previewLayer) {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        //填充模式
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    
    return _previewLayer;
}
- (AVCaptureSession *)session
{
    if (!_session) {
        //1.初始化捕捉会话
        //1.1.初始化
        _session = [[AVCaptureSession alloc] init];
        //1.2.设置分辨率
        if ([_session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
            [_session setSessionPreset:AVCaptureSessionPreset1280x720];
        }
    }
    return _session;
}

#pragma mark - init method ------
- (instancetype)initWithPreview:(UIView *)preview
{
    if (self = [super init]) {
        [self setupDefaultConfig];
        if (preview) {
            _cursorIconSize = CGSizeMake(50, 50);
            self.preview = preview;
            [self setupPreview];
        }
    }
    return self;
}

- (void)setupPreview
{
    [self.preview.layer insertSublayer:_previewLayer atIndex:0];
    
    self.previewLayer.frame = self.preview.frame;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapScreen:)];
    [self.preview addGestureRecognizer:tap];
    if (_showCursor) {
        self.cursorIconView.center = self.preview.center;
    }
    
    [self setFocusPoint:self.preview.center];
}
- (void)setShowCursor:(BOOL)showCursor
{
    _showCursor = showCursor;
    if (showCursor) {
        [self cursorIconView];
    }
    else {
        if (_cursorIconView) {
            [_cursorIconView removeFromSuperview];
            _cursorIconView = nil;
        }
    }
}

- (void)setupDefaultConfig
{
    //初始化捕捉会话
    [self session];
    //获得相机输入设备
    AVCaptureDevice *cameraDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (cameraDevice == nil) {
        WYLog(@"获取后置摄像头失败");
        return;
    }
    
    //根据相机输入设备创建相机输入源
    self.cameraDeviceInput = [self getCameraDeviceInput];
    if (self.cameraDeviceInput == nil) {
        return;
    }
    //添加输入源
    if ([self.session canAddInput:_cameraDeviceInput]) {
        [self.session addInput:_cameraDeviceInput];
    }
    [self previewLayer];
    [self addNotificationToCaptureDevice:cameraDevice];
    
    [self addNotificationToSession:self.session];
}
- (void)setupImageConfig
{
    //4.创建输出数据管理对象 用于获得输出数据
    [self imageOutput];
    
    //6.添加输出源
    if ([self.session canAddOutput:self.imageOutput]) {
        [self.session addOutput:self.imageOutput];
    }
    
    if (_audioDeviceInput) {
        BOOL contain = [self.session.inputs containsObject:_audioDeviceInput];
        if (contain) {
            [self.session removeInput:_audioDeviceInput];
        }
        _audioDeviceInput = nil;
    }
    
    if (_movieFileOutput) {
        BOOL contain = [self.session.outputs containsObject:_movieFileOutput];
        if (contain) {
            [self.session removeOutput:_movieFileOutput];
        }
        
        _movieFileOutput = nil;
    }
    
}
- (void)setupVideoConfig
{
    // 创建视频数据输出管理对象
    [self movieFileOutput];
    
    AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    if ([connection isVideoStabilizationSupported]) {
        // 通过将preferredVideoStabilizationMode属性设置为AVCaptureVideoStabilizationModeOff以外的值，当模式可用时，流经接收器的视频会稳定
        connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    
    if (_imageOutput) {
        [self.session removeOutput:_imageOutput];
        _imageOutput = nil;
    }
    if (!_audioDeviceInput) {
        _audioDeviceInput = [self getAudioDeviceInput];
    }
    
    if ([self.session canAddInput:_audioDeviceInput]) {
        [self.session addInput:_audioDeviceInput];
    }
    //添加输出源
    if ([self.session canAddOutput:self.movieFileOutput]) {
        [self.session addOutput:self.movieFileOutput];
    }
}
//屏幕旋转时调整视频预览图层的方向
-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
    AVCaptureConnection *captureConnection = [self.previewLayer connection];
    captureConnection.videoOrientation = (AVCaptureVideoOrientation)toInterfaceOrientation;
}

//旋转后重新设置大小
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    self.previewLayer.frame = self.preview.bounds;
}
- (void)addNotificationToSession:(AVCaptureSession *)session {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    //会话出错的通知
    [center addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:session];
    
    //会话成功开始运行时的通知 可以通过该通知知道AVCaptureSession的实例何时开始运行。
    [center addObserver:self selector:@selector(sessionDidStartRunning:) name:AVCaptureSessionDidStartRunningNotification object:session];
    
    //客户端可以观察AVCaptureSessionDidStopRunningNotification以知道AVCaptureSession的实例何时停止运行。 AVCaptureSession实例可能由于外部系统条件（例如设备进入睡眠或被用户锁定）而自动停止运行。
    [center addObserver:self selector:@selector(sessionDidStopRunning:) name:AVCaptureSessionDidStopRunningNotification object:session];
    
    //会话中断的通知
    /**
     客户端可以观察AVCaptureSessionWasInterruptedNotification以知道AVCaptureSession的实例何时已经被中断，例如，通过来电呼叫，或警报，或者需要控制所需硬件资源的另一应用。 在适当时，AVCaptureSession实例将自动停止运行以响应中断。
     从iOS 9.0开始，AVCaptureSessionWasInterruptedNotification userInfo字典包含一个AVCaptureSessionInterruptionReasonKey，指示中断的原因。
     */
    [center addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:session];
    
    //会话的中断结束的通知
    //客户端可以观察AVCaptureSessionInterruptionEndedNotification以知道何时AVCaptureSession的实例停止中断，例如，当电话呼叫结束，并且运行会话所需的硬件资源再次可用时。 在适当时，响应中断而先前停止的AVCaptureSession实例将在中断结束后自动重新启动。
    [center addObserver:self selector:@selector(sessionDidStopRunning:) name:AVCaptureSessionInterruptionEndedNotification object:session];
    
}
- (void)removeNotificationForSession:(AVCaptureSession *)session
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:AVCaptureSessionRuntimeErrorNotification object:session];
    
    [center removeObserver:self name:AVCaptureSessionDidStartRunningNotification object:session];
    
    [center removeObserver:self name:AVCaptureSessionDidStopRunningNotification object:session];
    
    [center removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:session];
    
    [center removeObserver:self name:AVCaptureSessionInterruptionEndedNotification object:session];
}
#pragma mark - 通知事件 ----------
/**
 会话中断的通知
 
 @param notification 通知
 */
- (void)sessionWasInterrupted:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    id  obj = notification.object;
    WYLog(@"会话中断.obj:%@ userInfo:%@", obj, userInfo);
}
/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
    NSDictionary *userInfo = notification.userInfo;
    id  obj = notification.object;
    /** userInfo字典包含键AVCaptureSessionErrorKey的NSError。*/
    WYLog(@"会话发生错误.obj:%@ userInfo:%@", obj, userInfo);
}

/**
 会话开始运行的通知
 
 @param notification 通知对象
 */
- (void)sessionDidStartRunning:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    id  obj = notification.object;
    WYLog(@"会话成功开始运行时的通知.obj:%@ userInfo:%@", obj, userInfo);
}

/**
 会话停止运行的同通知
 
 @param notification 通知对象
 */
- (void)sessionDidStopRunning:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    
    id  obj = notification.object;
    
    WYLog(@"会话停止运行的通知. obj:%@ userInfo:%@", obj,userInfo);
}


- (void)setCursorIconSize:(CGSize)cursorIconSize
{
    if (CGSizeEqualToSize(_cursorIconSize, cursorIconSize)) {
        return;
    }
    _cursorIconSize = cursorIconSize;
    if (!_showCursor) {
        return;
    }
    CGRect frame = self.cursorIconView.frame;
    frame.size = cursorIconSize;
    self.cursorIconView.frame = frame;
}
#pragma mark - 点击事件
- (void)tapScreen:(UITapGestureRecognizer *)tapGesture {
    CGPoint point = [tapGesture locationInView:tapGesture.view];
    [self setFocusPoint:point];
    
    //UI坐标转换成摄像头坐标
    CGPoint cameraPoint = [self.previewLayer captureDevicePointOfInterestForPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}
/* 设置光标位置 */
- (void)setFocusPoint:(CGPoint)point {
    if (!_showCursor) {
        return;
    }
    CGRect frame = self.cursorIconView.frame;
    self.cursorIconView.center = point;
    self.cursorIconView.transform = CGAffineTransformMakeScale(1.5, 1.5);
    self.cursorIconView.alpha = 1.0;
    frame = self.cursorIconView.frame;
    [UIView animateWithDuration:1.0 animations:^{
        self.cursorIconView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.cursorIconView.alpha = 0;
    }];
}

- (AVCaptureDeviceInput *)getCameraDeviceInput
{
    AVCaptureDevice *cameraDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (cameraDevice == nil) {
        WYLog(@"获取后置摄像头失败");
        return nil;
    }
    
    //根据相机输入设备创建相机输入源
    NSError *error = nil;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&error];
    if (error) {
        WYLog(@"创建相机输入源错误:%@", error);
        return nil;
    }
    return deviceInput;
}
- (AVCaptureDeviceInput *)getAudioDeviceInput
{
    //获得话筒输入设备
    AVCaptureDevice *audioDevice = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio].firstObject;
    
    //创建话筒输入源
    NSError *error = nil;
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (error) {
        WYLog(@"创建话筒输入源出错:%@", error);
        return nil;
    }
    return audioDeviceInput;
}

/* 根据摄像头位置来获取摄像头 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition)position {
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in cameras) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

- (void)startRunning
{
    if ([self.session isRunning]) {
        [self.session stopRunning];
    }
    [self.session startRunning];
}
- (void)stopRunning
{
    if ([self.session isRunning]) {
        [self.session stopRunning];
    }
}

/** 开始录制视频 */
- (void)startRecordingVideoToFileURL:(NSURL *)outputFileURL {
    
    if (!_movieFileOutput) {
        [self setupVideoConfig];
    }
    if (outputFileURL == nil) {
        WYLog(@"outputFileURL 为 nil");
        return;
    }
    BOOL isRecording = [self.movieFileOutput isRecording];
    if (isRecording) {
        WYLog(@"正在录制视频");
        return;
    }
    
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //预览图层和视频方向保持一致
    captureConnection.videoOrientation = [self.previewLayer connection].videoOrientation;
    
    [self.movieFileOutput startRecordingToOutputFileURL:outputFileURL recordingDelegate:self];
}
/** 结束录制视频 */
- (void)stopRecordingVideo {
    if ([self.movieFileOutput isRecording]) {
        [self.movieFileOutput stopRecording];
    }
}
- (void)takePhoto:(void(^)(UIImage * image))callBack
{
    if (!_imageOutput) {
        [self setupImageConfig];
    }
    //1.根据数据输出管理对象（输出源）获得链接
    AVCaptureConnection *connection = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    //2.根据连接取得输出数据
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        //获取图像数据
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image = [UIImage imageWithData:imageData];
        if (callBack) {
            callBack(image);
        }
    }];
}
/**
 *  移除所有通知
 */
-(void)removeNotification{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
}
- (void)dealloc {
    [self removeNotification];
    WYLog(@"dealloc ------ ");
}

/**
 获取当前相机位置

 @return return value description
 */
- (AVCaptureDevicePosition)getCurrentCameraPosition
{
    AVCaptureDevice *oldCaptureDevice = [self.cameraDeviceInput device];
    AVCaptureDevicePosition currentPosition = oldCaptureDevice.position;
    return currentPosition;
}

- (void)switchCameraToPostion:(AVCaptureDevicePosition)targetPosition
{
    //1.获取原来的输入设备 根据数据输入管理对象获取
    AVCaptureDevice *oldCaptureDevice = [self.cameraDeviceInput device];
    //2.移除输入设备的通知
    [self removeNotificationFromCaptureDevice:oldCaptureDevice];

    //3.根据摄像头的位置获取当前的输入设备
    AVCaptureDevice *currentCaptureDevice = [self getCameraDeviceWithPosition:targetPosition];
    
    //4.添加对当前输入设备的通知
    [self addNotificationToCaptureDevice:currentCaptureDevice];
    
    //5.创建当前设备的数据输入管理对象
    NSError *error = nil;
    AVCaptureDeviceInput *currentInput = [[AVCaptureDeviceInput alloc] initWithDevice:currentCaptureDevice error:&error];
    if (error) {
        WYLog(@"创建输入源失败，%@", error);
        return;
    }
    //6.添加新的数据管理对象到捕捉会话
    //6.1.开始设置
    [self.session beginConfiguration];
    //6.2.移除原有的输入源
    [self.session removeInput:self.cameraDeviceInput];
    
    //6.3.添加新的输入源
    if ([self.session canAddInput:currentInput]) {
        [self.session addInput:currentInput];
        //.标记当前的输入源
        self.cameraDeviceInput = currentInput;
    }
    //6.4.提交设置
    [self.session commitConfiguration];
}
/**
 切换相机位置

 @return 切换之后的相机位置
 */
- (AVCaptureDevicePosition)switchCameraPosition
{
    // 1.获取当前的相机位置
    AVCaptureDevicePosition currentPosition = [self getCurrentCameraPosition];
    
    // 2.获取要切换的位置
    AVCaptureDevicePosition targetPosition = AVCaptureDevicePositionFront;
    if (currentPosition == AVCaptureDevicePositionFront || AVCaptureDevicePositionUnspecified) {
        targetPosition = AVCaptureDevicePositionBack;
    }
    return targetPosition;
}
/**
 切换摄像头
 */
- (void)switchCamera
{
    AVCaptureDevicePosition targetPosition = [self switchCameraPosition];
    
    [self switchCameraToPostion:targetPosition];
}


/* 添加通知 监测捕获区域发生的变化 */
- (void)addNotificationToCaptureDevice:(AVCaptureDevice *)device {
    //1.先锁住输入设备
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        //添加区域改变捕获通知必须首先设置设备允许捕获
        //表明接收方是否应该监控领域的变化(如照明变化，实质移动等) 可以通过AVCaptureDeviceSubjectAreaDidChangeNotification通知监测 我们可以希望重新聚焦，调整曝光白平衡等的主题区域 在设置该属性之前必须调用lockForConfiguration方法锁定设备配置
        device.subjectAreaChangeMonitoringEnabled = YES;
    }];
    
    //2.监测通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(areaChanged:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceWasConnected:) name:AVCaptureDeviceWasConnectedNotification object:device];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceWasDisconnected:) name:AVCaptureDeviceWasDisconnectedNotification object:device];
}
#pragma mark -设备捕获区域发生变化
- (void)areaChanged:(NSNotification *)notification {
    WYLog(@"捕获区域改变...");
}
- (void)deviceWasConnected:(NSNotification *)notification {
    WYLog(@"device becomes available on the system.（设备在系统上可用） deviceWasConnected ...");
}

- (void)deviceWasDisconnected:(NSNotification *)notification {
    WYLog(@"device becomes unavailable on the system.（设备在系统中不可用） deviceWasDisconnected ...");
}



/* 移除监控输入设备通知 */
- (void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)device {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
}

/**
 设置聚焦和曝光模式

 @param focusMode 聚焦模式
 @param exposureMode 曝光模式
 @param point 位置
 */
- (void)focusWithMode:(AVCaptureFocusMode)focusMode
         exposureMode:(AVCaptureExposureMode)exposureMode
              atPoint:(CGPoint)point
{
    //设置曝光模式和聚焦模式 先锁住输入设置
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        //设置聚焦模式
        if ([device isFocusModeSupported:focusMode]) {
            [device setFocusMode:focusMode];
        }
        //设置曝光模式
        if ([device isExposureModeSupported:exposureMode]) {
            [device setExposureMode:exposureMode];
        }
        //设置聚焦点
        if ([device isFocusPointOfInterestSupported]) {
            [device setFocusPointOfInterest:point];
        }
        //设置曝光点
        if ([device isExposurePointOfInterestSupported]) {
            [device setExposurePointOfInterest:point];
        }
        
    }];
}


/* 定义闪光灯开闭及自动模式功能，注意无论是设置闪光灯、白平衡还是其他输入设备属性，在设置之前必须先锁定配置，修改完后解锁。 */
/* 改变设备属性 进行的是锁住设备操作 通过block返回输入设备 */
- (void)changeDeviceProperty:(PropertyChangeBlock)block {
    //1.获得设备
    AVCaptureDevice *device = self.cameraDeviceInput.device;
    NSError *error = nil;
    //2.锁住设备
    BOOL success = [device lockForConfiguration:&error];
    if (success) {
        //1.锁定成功 通过block返回输入设备
        block(device);
        //2.解锁
        [device unlockForConfiguration];
    }
    else {
        WYLog(@"设置设备属性过程发生错误，错误信息%@", error.localizedDescription);
    }
}
#pragma mark - 设置闪光灯模式
- (void)setFlashMode:(AVCaptureFlashMode)mode {
    //先锁住设备
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        if ([device isFlashModeSupported:mode]) {
            [device setFlashMode:mode];
        }
    }];
}

/**
 设置聚焦模式

 @param mode mode description
 */
- (void)setFocusMode:(AVCaptureFocusMode)mode {
    //先锁住设备
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        if ([device isFocusModeSupported:mode]) {
            [device setFocusMode:mode];
        }
    }];
}

/**
 设置曝光模式

 @param mode mode description
 */
- (void)setExposureMode:(AVCaptureExposureMode)mode {
    //先锁住设备
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        //设置曝光模式
        if ([device isExposureModeSupported:mode]) {
            [device setExposureMode:mode];
        }
    }];
}



#pragma mark - AVCaptureFileOutputRecordingDelegate

/**
 必须实现的代理 输入源完成数据写入 或者调用
 - (void)startRecordingToOutputFileURL:(NSURL*)outputFileURL recordingDelegate:(id<AVCaptureFileOutputRecordingDelegate>)delegate;方法，或者调用stopRecording方法，或者因为发生了由错误参数描述的错误（如果没有发生错误， 错误参数将为nil）。 即使没有数据成功写入文件，也会请求调用此方法。
 
 @param captureOutput 输入源
 @param outputFileURL 文件URL。
 @param connections AVCaptureConnection对象数组，提供写入文件的数据。
 @param error 描述什么导致文件停止记录的错误，如果没有错误，则为nil
 */
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray *)connections
                error:(NSError *)error
{
    WYLog(@"视频录制完成");
    
    if (self.didFinishRecordingVideo) {
        self.didFinishRecordingVideo(captureOutput, outputFileURL, connections, error);
    }
}

/**
 开始录制
 当文件输出开始将数据写入文件时，将调用此方法。 如果错误条件阻止写入任何数据，则可能无法调用此方法
 
 @param captureOutput 输入源
 @param fileURL 文件路径
 @param connections AVCaptureConnection对象数组，提供写入文件的数据
 */
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
      fromConnections:(NSArray *)connections
{
    WYLog(@"开始录制...");
    if (self.didStartRecordingVideo) {
        self.didStartRecordingVideo(captureOutput, fileURL, connections);
    }
}

@end


