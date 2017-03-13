//
//  RecordVideoViewController.m
//  RecordVideoAndTakePhoto
//
//  Created by liweiyou on 17/3/9.
//  Copyright © 2017年 yons. All rights reserved.
//

#import "RecordVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>


typedef void(^DevicePropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface RecordVideoViewController ()<AVCaptureFileOutputRecordingDelegate>
/** 媒体捕捉会话 */
@property (nonatomic , strong) AVCaptureSession *session;
/** 数据输入管理对象 相机*/
@property (nonatomic , strong) AVCaptureDeviceInput *cameraDeviceInput;
/** 数据输入管理对象 麦克风 */
@property (nonatomic , strong) AVCaptureDeviceInput *audioDeviceInput;
/** 预览层 */
@property (nonatomic , strong) AVCaptureVideoPreviewLayer *previewLayer;
/** 输出源 数据输出管理对象 */
@property (nonatomic , strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;


- (IBAction)startRecording:(id)sender;
- (IBAction)stopRecording:(id)sender;
- (IBAction)switchCamera:(id)sender;

@end

@implementation RecordVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //初始化捕捉会话
    _session = [[AVCaptureSession alloc] init];
    if ([_session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        [_session setSessionPreset:AVCaptureSessionPreset1280x720];
    }
    
    //获得相机输入设备
    AVCaptureDevice *cameraDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (cameraDevice == nil) {
        NSLog(@"获取后置摄像头失败");
        return;
    }
    
    //根据相机输入设备创建相机输入源
    NSError *error = nil;
    _cameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&error];
    if (error) {
        NSLog(@"%@", error.localizedDescription);
        return;
    }
    
    //获得话筒输入设备
    AVCaptureDevice *audioDevice = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio].firstObject;
    //创建话筒输入源
    _audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    
    //创建数据输出管理对象
    _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    //添加输入源
    if ([_session canAddInput:_cameraDeviceInput]) {
        [_session addInput:_cameraDeviceInput];
        
        AVCaptureConnection *connection = [_movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported]) {
        
            connection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;//通过将preferredVideoStabilizationMode属性设置为AVCaptureVideoStabilizationModeOff以外的值，当模式可用时，流经接收器的视频会稳定
        }
        
    }
    
    if ([_session canAddInput:_audioDeviceInput]) {
        [_session addInput:_audioDeviceInput];
    }
    
    //添加输出源
    if ([_session canAddOutput:_movieFileOutput]) {
        [_session addOutput:_movieFileOutput];
    }
    
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
    _previewLayer.frame = self.view.bounds;
    _previewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    
    [self.view.layer insertSublayer:self.imageView.layer atIndex:0];
    [self.view.layer insertSublayer:_previewLayer atIndex:0];
    
//    [self.view.layer insertSublayer:_previewLayer below:self.imageView.layer];
    [self addNotificationToCaptureDevice:cameraDevice];
    
    [self addNotificationToSession:_session];
    
    [self addGestureToView];
}
#pragma mark -添加聚焦手势
- (void)addGestureToView {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    [self.view addGestureRecognizer:tap];
}
#pragma mark- 聚焦手势的点击事件
- (void)tapAction:(UITapGestureRecognizer *)tap {
    
    //1.获得点击的位置
    CGPoint uiPoint = [tap locationInView:self.view];
    //2.UI位置转化为设备的位置
//    将图层坐标中的点转换为捕获设备的坐标空间中的兴趣点，向图层提供输入
    CGPoint devicePoint = [self.previewLayer captureDevicePointOfInterestForPoint:uiPoint];
    
    [self changeDeviceMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:devicePoint];
    //设置聚焦光标的位置 是UI坐标
    [self setFocusCursorWithPoint:uiPoint];
}
/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
-(void)setFocusCursorWithPoint:(CGPoint)point{
    self.imageView.center=point;
    self.imageView.transform=CGAffineTransformMakeScale(1.5, 1.5);
    self.imageView.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.imageView.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.imageView.alpha=0;
    }];
}

- (void)changeDeviceMode:(AVCaptureFocusMode)focusMode
            exposureMode:(AVCaptureExposureMode)exposureMode
                 atPoint:(CGPoint)point
{
    //1.改变设备属性先锁定设备
    [self lockDeviceWithBlock:^(AVCaptureDevice *captureDevice) {
        //设置聚焦模式
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
        //设置曝光模式
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
        //设置聚焦点
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        //设置曝光点
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
        
    }];
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

/**
 会话的中断结束的通知

 @param notification 通知对象
 */
- (void)sessionInterruptionEnded:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    
    NSLog(@"会话结束中断.%@", userInfo);
}
/**
 会话中断的通知

 @param notification 通知
 */
- (void)sessionWasInterrupted:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    
    NSLog(@"会话中断.%@", userInfo);
}
/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
    NSDictionary *userInfo = notification.userInfo;
    /**
     userInfo字典包含键AVCaptureSessionErrorKey的NSError。
     */
    NSLog(@"会话发生错误.%@", userInfo);
}

/**
 会话开始运行的通知

 @param notification 通知对象
 */
- (void)sessionDidStartRunning:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    /**
     
     */
    NSLog(@"会话成功开始运行时的通知.%@", userInfo);
}

/**
 会话停止运行的同通知

 @param notification 通知对象
 */
- (void)sessionDidStopRunning:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    /**
     
     */
    NSLog(@"会话停止运行的通知.%@", userInfo);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_session startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_session stopRunning];
}
/** 改变设备属性的统一操作 定义闪光灯开闭以及模式功能，无论是设置闪光灯、白平衡还是其他输入设备的功能，在设置之前必须先锁定配置， 修改完之后再解锁 */
- (void)lockDeviceWithBlock:(DevicePropertyChangeBlock)block {
    AVCaptureDevice *device = self.cameraDeviceInput.device;
    NSError *error = nil;
    
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    BOOL success = [device lockForConfiguration:&error];
    if (success) {
        block(device);
        [device unlockForConfiguration];
    }else {
        NSLog(@"锁住设备失败，%@", error);
    }
}

/** 给输入设备添加通知 监控区域发生改变 */
- (void)addNotificationToCaptureDevice:(AVCaptureDevice *)device {
    //先锁住设备
    [self lockDeviceWithBlock:^(AVCaptureDevice *captureDevice) {
        //添加区域改变捕获通知必须首先设置设备允许捕获
        //表明接收方是否应该监控领域的变化(如照明变化，实质移动等) 可以通过AVCaptureDeviceSubjectAreaDidChangeNotification通知监测 我们可以希望重新聚焦，调整曝光白平衡等的主题区域 在设置该属性之前必须调用lockForConfiguration方法锁定设备配置
        captureDevice.subjectAreaChangeMonitoringEnabled = YES;
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
}
- (void)removeNotificationFromDevice:(AVCaptureDevice *)device {
  
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
    
}
- (void)areaChange:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    
    NSLog(@"监控区域发生改变%@", userInfo);
}
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition)position {
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in cameras) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

#pragma mark - 开始录制
/** 开始录制 */
- (IBAction)startRecording:(UIButton *)sender {
    sender.enabled = NO;
    
    _stopButton.enabled = YES;
    
    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"myVideo.mp4"];
    
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    
    [self.movieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    
}
#pragma mark - 结束录制
/** 结束录制 */
- (IBAction)stopRecording:(UIButton *)sender {
    sender.enabled = NO;
    _startButton.enabled = YES;
    if ([_session isRunning]) {
        [_session stopRunning];
    }
    if ([self.movieFileOutput isRecording]) {
        [self.movieFileOutput stopRecording];
    }
}
#pragma mark - 切换摄像头
/** 切换摄像头 */
- (IBAction)switchCamera:(id)sender {
    //1.获取当前的输入设备 根据当前输入源获取
    AVCaptureDevice *oldCaptureDevice = self.cameraDeviceInput.device;
    //2.移除通知
    [self removeNotificationFromDevice:oldCaptureDevice];
    //3.切换摄像头位置
    //3.1.获得原来摄像头的位置
    AVCaptureDevicePosition oldPosition = oldCaptureDevice.position;
    //3.2.切换位置
    AVCaptureDevicePosition currentPosition = AVCaptureDevicePositionFront;
    if (oldPosition == AVCaptureDevicePositionFront || oldPosition == AVCaptureDevicePositionUnspecified) {
        currentPosition = AVCaptureDevicePositionBack;
    }
    
    //4.获得当前输入设备
    AVCaptureDevice *currentCaptureDevice = [self getCameraDeviceWithPosition:currentPosition];
    
    //5.对当前输入设备添加通知
    [self addNotificationToCaptureDevice:currentCaptureDevice];
    
    //6.创建当前输入源
    NSError *error = nil;
    AVCaptureDeviceInput *currentInput = [AVCaptureDeviceInput deviceInputWithDevice:currentCaptureDevice error:&error];
    if (error) {
        NSLog(@"创建输入源失败，%@", error);
        return;
    }
    
    //7.切换输入源
    //7.1.开启设置
    [_session beginConfiguration];
    //7.2.移除原来的输入源
    [_session removeInput:self.cameraDeviceInput];
    //7.3.添加现在的输入源
    if ([_session canAddInput:currentInput]) {
        [_session addInput:currentInput];
        //标记当前的输入源
        _cameraDeviceInput = currentInput;
    }
    
    //7.4.提交设置
    [_session commitConfiguration];
    
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
    NSLog(@"视频录制完成");
    ALAssetsLibrary *assets = [[ALAssetsLibrary alloc] init];
    [assets writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"保存视频失败，%@", error);
            return ;
        }
        NSLog(@"保存视频成功");
    }];
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
     NSLog(@"开始录制...");
}

@end
