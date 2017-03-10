//
//  TakePhotoViewController.m
//  RecordVideoAndTakePhoto
//
//  Created by liweiyou on 17/3/9.
//  Copyright © 2017年 yons. All rights reserved.
//

#import "TakePhotoViewController.h"
#import <AVFoundation/AVFoundation.h>
/**
 AVCaptureSession: 媒体（音频、视频）捕捉会话，负责把捕捉的音视频数据输出到输出设备，一个捕捉会话可以有多个输入输出
 AVCaptureDevice: 输入设备 包括摄像头、话筒等，通过该对象可以设置物理设备的属性（相机的聚焦白平衡等）
 AVCaptureDeviceInput: 输入数据管理对象，可以根据AVCaptureDevice创建对应的AVCaptureDeviceInput对象，该对象将会被添加到AVCaptureSession中管理
 
 AVCaptureOutput:输出数据管理对象，用于接受各类输出数据，通常使用其子类AVCaptureAudioDataOutput、AVCaptureStillImageOutput、AVCaptureVideoDataOutput、AVCaptureFileOutput，该对象将会被添加到AVCaptureSession中管理。注意：前面几个对象的输出数据都是NSData类型，而AVCaptureFileOutput代表数据以文件形式输出，类似的，AVCcaptureFileOutput也不会直接创建使用，通常会使用其子类：AVCaptureAudioFileOutput、AVCaptureMovieFileOutput。当把一个输入或者输出添加到AVCaptureSession
 
 AVCaptrueVideoPreviewLayer: 相机拍摄预览图层，是CAPlayer的子类，使用该对象可以实时查看拍摄和视频录制的效果，创建该对象需要指定对应的AVCaptureSession对象
 
 */


typedef void (^PropertyChangeBlock) (AVCaptureDevice *device);

@interface TakePhotoViewController ()
/* 媒体捕捉会话 */
@property (nonatomic , strong) AVCaptureSession *session;
/** 数据输入管理对象 */
@property (nonatomic , strong) AVCaptureDeviceInput *captureDeviceInput;
/* 输出数据管理对象 */
@property (nonatomic , strong) AVCaptureStillImageOutput *imageOutput;
/* 预览图层 */
@property (nonatomic , strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (weak, nonatomic) IBOutlet UIButton *takePhotoButton;
@property (weak, nonatomic) IBOutlet UIButton *flashAutoButton;
@property (weak, nonatomic) IBOutlet UIButton *falshOffButton;
@property (weak, nonatomic) IBOutlet UIButton *falshOnButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

- (IBAction)takePhoto:(id)sender;
- (IBAction)flashAuto:(id)sender;
- (IBAction)offfalsh:(id)sender;
- (IBAction)onFlash:(id)sender;
- (IBAction)switchCamera:(id)sender;

@end

@implementation TakePhotoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //1.初始化捕捉会话
    //1.1.初始化
    _session = [[AVCaptureSession alloc] init];
    //1.2.设置分辨率
    if ([_session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        [_session setSessionPreset:AVCaptureSessionPreset1280x720];
    }
    
    //2.获得输入设备 后置摄像头
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (captureDevice == nil) {
        NSLog(@"获取后置摄像头失败");
        return;
    }
    NSError *error = nil;
    //3.根据输入设备创建输入数据管理对象
    AVCaptureDeviceInput *captureInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    self.captureDeviceInput = captureInput;
    if (error) {
        NSLog(@"取得设备输入对象时出错，%@", error.localizedDescription);
        return;
    }
    
    //4.创建输出数据管理对象 用于获得输出数据
    AVCaptureStillImageOutput *imageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    [imageOutput setOutputSettings:outputSettings];//输出设置
    self.imageOutput = imageOutput;
    
    //5.添加输入设备管理对象到捕捉会话
    if ([_session canAddInput:_captureDeviceInput]) {
        [_session addInput:_captureDeviceInput];
    }
    
    //6.添加输出源
    if ([_session canAddOutput:_imageOutput]) {
        [_session addOutput:_imageOutput];
    }
    
    //7.设置预览图层
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
    _previewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    _previewLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:_previewLayer atIndex:0];
    
    //8.给设备添加通知 监测监控区域的变化
    [self addNotificationToCaptureDevice:captureDevice];
    
    //9.添加手势
    [self addGestureToView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [_session startRunning];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [_session stopRunning];
}

- (void)addGestureToView {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapScreen:)];
    [self.view addGestureRecognizer:tap];
}
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture {
    CGPoint point = [tapGesture locationInView:self.view];
    //UI坐标转换成摄像头坐标
    CGPoint cameraPoint = [self.previewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusPoint:cameraPoint];
    
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}
/* s设置聚焦和曝光模式 */
- (void)focusWithMode:(AVCaptureFocusMode)focusMode
         exposureMode:(AVCaptureExposureMode)exposeMode
              atPoint:(CGPoint)point
{
    //设置曝光模式和聚焦模式 先锁住输入设置
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        if ([device isFocusModeSupported:focusMode]) {
            [device setFocusMode:focusMode];
        }
        
        if ([device isExposureModeSupported:exposeMode]) {
            [device setExposureMode:exposeMode];
        }
        
        if ([device isFocusPointOfInterestSupported]) {
            [device setFocusPointOfInterest:point];
        }
        
        if ([device isExposurePointOfInterestSupported]) {
            [device setExposurePointOfInterest:point];
        }
        
    }];
}
/* 设置光标位置 */
- (void)setFocusPoint:(CGPoint)point {
    self.imageView.center = point;
    
    self.imageView.transform = CGAffineTransformMakeScale(1.5, 1.5);
    self.imageView.alpha = 1;
    
    [UIView animateWithDuration:1.0 animations:^{
        self.imageView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.imageView.alpha = 0;
    }];
    
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
    
}
/* 移除监控输入设备通知 */
- (void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)device {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
}

#pragma mark -设备捕获区域发生变化
- (void)areaChanged:(NSNotification *)notification {
       NSLog(@"捕获区域改变...");
}

/* 定义闪光灯开闭及自动模式功能，注意无论是设置闪光灯、白平衡还是其他输入设备属性，在设置之前必须先锁定配置，修改完后解锁。 */
/* 改变设备属性 进行的是锁住设备操作 通过block返回输入设备 */
- (void)changeDeviceProperty:(PropertyChangeBlock)block {
    //1.获得设备
    AVCaptureDevice *device = self.captureDeviceInput.device;
    NSError *error;
    //2.锁住设备
    BOOL success = [device lockForConfiguration:&error];
    if (success) {
        //1.锁定成功 通过block返回输入设备
        block(device);
        //2.解锁
        [device unlockForConfiguration];
    }
    else {
        NSLog(@"设置设备属性过程发生错误，错误信息%@", error.localizedDescription);
    }
    
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
/**
 *  移除所有通知
 */
-(void)removeNotification{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
}
-(void)dealloc{
    [self removeNotification];
    NSLog(@"dealloc ------ ");
}
#pragma mark -拍照
- (IBAction)takePhoto:(id)sender {
    //1.根据数据输出管理对象（输出源）获得链接
    AVCaptureConnection *connection = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    //2.根据连接取得输出数据
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        //获取图像数据
        NSData *imageData=[AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image=[UIImage imageWithData:imageData];
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }];
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
#pragma mark -自动闪光
- (IBAction)flashAuto:(id)sender {
    [self setFlashMode:AVCaptureFlashModeAuto];
}

#pragma mark -关闭闪光
- (IBAction)offfalsh:(id)sender {
    [self setFlashMode:AVCaptureFlashModeOff];
}

#pragma mark -开启闪光
- (IBAction)onFlash:(id)sender {
    [self setFlashMode:AVCaptureFlashModeOn];
}

#pragma mark -切换摄像头
/* 切换摄像头的过程就是将原有的输入源移除 添加新的输入源到会话中 */
- (IBAction)switchCamera:(id)sender {
    //1.获取原来的输入设备 根据数据输入管理对象获取
    AVCaptureDevice *oldCaptureDevice = [self.captureDeviceInput device];
    //2.移除输入设备的通知
    [self removeNotificationFromCaptureDevice:oldCaptureDevice];
    
    //3.切换摄像头的位置
    //3.1.获取当前的位置
    AVCaptureDevicePosition currentPosition = oldCaptureDevice.position;
    //3.2.获取要切换的位置
    AVCaptureDevicePosition targetPosition = AVCaptureDevicePositionFront;
    if (currentPosition == AVCaptureDevicePositionFront || AVCaptureDevicePositionUnspecified) {
        targetPosition = AVCaptureDevicePositionBack;
    }
    
    //4.根据摄像头的位置获取当前的输入设备
    AVCaptureDevice *currentCaptureDevice = [self getCameraDeviceWithPosition:targetPosition];
    
    //5.添加对当前输入设备的通知
    [self addNotificationToCaptureDevice:currentCaptureDevice];
    
    //6.创建当前设备的数据输入管理对象
    AVCaptureDeviceInput *currentInput = [[AVCaptureDeviceInput alloc] initWithDevice:currentCaptureDevice error:nil];
    
    //7.添加新的数据管理对象到捕捉会话
    //7.1.开始设置
    [_session beginConfiguration];
    //7.2.移除原有的输入源
    [_session removeInput:self.captureDeviceInput];
    
    //7.3.添加新的输入源
    if ([_session canAddInput:currentInput]) {
        [_session addInput:currentInput];
        //.标记当前的输入源
        self.captureDeviceInput = currentInput;
    }
    
    
    //7.4.提交设置
    [_session commitConfiguration];
}
@end
