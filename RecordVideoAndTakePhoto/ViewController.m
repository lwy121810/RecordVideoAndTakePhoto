//
//  ViewController.m
//  RecordVideoAndTakePhoto
//
//  Created by liweiyou on 17/3/9.
//  Copyright © 2017年 yons. All rights reserved.
//

#import "ViewController.h"
#import "TakePhotoViewController.h"
#import "RecordVideoViewController.h"

@interface ViewController ()
- (IBAction)takePhtoo:(id)sender;
- (IBAction)video:(id)sender;

@end

@implementation ViewController


- (IBAction)takePhtoo:(id)sender {
    TakePhotoViewController *vc = [[TakePhotoViewController alloc] init];
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)video:(id)sender {
    RecordVideoViewController *vc = [[RecordVideoViewController alloc] init];
    
    [self.navigationController pushViewController:vc animated:YES];
}
@end
