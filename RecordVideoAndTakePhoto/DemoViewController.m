//
//  DemoViewController.m
//  RecordVideoAndTakePhoto
//
//  Created by lwy1218 on 2018/1/4.
//  Copyright © 2018年 lwy1218. All rights reserved.
//

#import "DemoViewController.h"
#import "WYAVManager.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface DemoViewController ()
{
    UIButton *_currentButton;
}
@property (nonatomic , strong) WYAVManager *avManager;
@property (nonatomic , strong) UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UIButton *takeButton;
@property (weak, nonatomic) IBOutlet UIButton *switchCameraButton;
- (IBAction)switchCamera:(UIButton *)sender;
- (IBAction)takePhoto:(UIButton *)sender;
@property (weak, nonatomic) IBOutlet UIButton *videoButton;
@property (weak, nonatomic) IBOutlet UIButton *photoButton;
- (IBAction)chooseVideo:(id)sender;
- (IBAction)choosePhoto:(UIButton *)sender;
@property (nonatomic , assign) BOOL isRecordVideo;
@property (nonatomic , assign) NSInteger index;
@property (nonatomic, strong) dispatch_source_t timer;
@end

@implementation DemoViewController
- (WYAVManager *)avManager
{
    if (!_avManager) {
        _avManager = [[WYAVManager alloc] initWithPreview:self.view];
    }
    return _avManager;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.avManager startRunning];
    
    __weak typeof(self)weakSelf = self;
    self.avManager.didFinishRecordingVideo = ^(AVCaptureFileOutput *captureOutput, NSURL *fileURL, NSArray *connections, NSError *error) {
        
        ALAssetsLibrary *assets = [[ALAssetsLibrary alloc] init];
        [assets writeVideoAtPathToSavedPhotosAlbum:fileURL completionBlock:^(NSURL *assetURL, NSError *error) {
            if (error) {
                NSLog(@"保存视频失败，%@", error);
                [weakSelf showMessage:error.localizedDescription title:@"保存视频失败"];
                return ;
            }
            [weakSelf showMessage:nil title:@"保存视频到相簿成功"];
            NSLog(@"保存视频成功");
        }];
    };
}
- (void)showMessage:(NSString *)message title:(NSString *)title
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self.avManager stopRunning];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    
    _index = 0;
    [self.takeButton setTitle:@"拍照" forState:UIControlStateNormal];
    self.photoButton.selected = YES;
    _currentButton = self.photoButton;
    
    [self.takeButton setTitle:@"暂停" forState:UIControlStateSelected];
    
    UILabel *label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    self.navigationItem.titleView = label;
    self.timeLabel = label;
    
    self.timeLabel.frame = CGRectMake(0, 0, 100, 40);
    
    UIBarButtonItem *right = [[UIBarButtonItem alloc] initWithTitle:@"不显示光标" style:UIBarButtonItemStyleDone target:self action:@selector(showCursor:)];
    self.navigationItem.rightBarButtonItem = right;
}
- (void)showCursor:(UIBarButtonItem *)item
{
    item.title = self.avManager.showCursor ? @"不显示光标":@"显示光标";
    self.avManager.showCursor = !self.avManager.showCursor;
}
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopTimer];
}

- (IBAction)switchCamera:(UIButton *)sender {
    [self.avManager switchCamera];
}
- (void)setTimeText:(NSInteger)count
{
    
    int minute = (int)(count / 60);
    int second = (int)(count % 60);
    
    self.timeLabel.text = [NSString stringWithFormat:@"%02d:%02d",minute,second];
}
- (void)startTimer
{
    __block int count = 0;
    
    // 获得队列
    dispatch_queue_t queue = dispatch_get_main_queue();
    
    // 创建一个定时器
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
    uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);
    dispatch_source_set_timer(self.timer, start, interval, 0);
    
    // 设置回调
    dispatch_source_set_event_handler(self.timer, ^{
        count++;
        [self setTimeText:count];
    });
    
    // 启动定时器
    dispatch_resume(self.timer);
}
- (void)stopTimer
{
    if (self.timer) {
        // 取消定时器
        dispatch_cancel(self.timer);
        self.timer = nil;
    }
}
- (IBAction)takePhoto:(UIButton *)sender {
  
    if (_isRecordVideo) {
        if (sender.selected) {
            [self stopTimer];
            [self.avManager stopRecordingVideo];
        }
        else {
            [self startTimer];
            
            _index++;
            NSString *name = [NSString stringWithFormat:@"my_%ld_Video.mp4",_index];
            NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:name];
            
            NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
            
            [self.avManager startRecordingVideoToFileURL:fileUrl];
        }
        sender.selected = !sender.selected;
    }
    else {
        [self.avManager takePhoto:^(UIImage *image) {
            self.iconView.image = image;
            /// 写入相册
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        }];
    }
}
- (IBAction)chooseVideo:(id)sender {
    UIButton *button = (UIButton *)sender;
    if (_currentButton == button) {
        return;
    }
    _currentButton.selected = NO;
    _currentButton = button;
    _currentButton.selected = YES;
    
    _isRecordVideo = YES;
    self.takeButton.selected = NO;
    [self.takeButton setTitle:@"录制" forState:UIControlStateNormal];
}

- (IBAction)choosePhoto:(UIButton *)sender {
    
    if (_currentButton == sender) {
        return;
    }
    
    _currentButton.selected = NO;
    _currentButton = sender;
    _currentButton.selected = YES;
    
    _isRecordVideo = NO;
    self.takeButton.selected = NO;
    [self.takeButton setTitle:@"拍照" forState:UIControlStateNormal];
}
@end
