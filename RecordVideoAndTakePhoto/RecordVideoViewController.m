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

@interface RecordVideoViewController ()
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
    
    [self.view.layer insertSublayer:_previewLayer atIndex:0];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_session startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_session stopRunning];
}

- (void)lockDeviceWithBlock:(DevicePropertyChangeBlock)block {
    AVCaptureDevice *device = self.cameraDeviceInput.device;
    NSError *error = nil;
    BOOL success = [device lockForConfiguration:&error];
    if (success) {
        block(device);
        [device unlockForConfiguration];
    }else {
        NSLog(@"锁住设备失败，%@", error);
    }
}


- (void)addNotificationToCaptureDevice:(AVCaptureDevice *)device {
    [self lockDeviceWithBlock:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled = YES;
    }];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
}
- (void)removeNotificationFromDevice:(AVCaptureDevice *)device {
  
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
    
}
- (void)areaChange:(NSNotification *)notification {
    
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


/** 开始录制 */
- (IBAction)startRecording:(id)sender {
}
/** 结束录制 */
- (IBAction)stopRecording:(id)sender {
}
/** 切换摄像头 */
- (IBAction)switchCamera:(id)sender {
    //1.获取当前的输入设备 根据当前输入源获取
    AVCaptureDevice *oldCaptureDevice = self.cameraDeviceInput.device;
    //2.移除通知
    
    //3.切换摄像头位置
    
    //4.获得当前输入设备
    
    //5.创建当前输入源
    
    //6.切换输入源
    
}
@end
