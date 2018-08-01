//
//  ViewController.m
//  CaptureAudio
//
//  Created by zhanghaidi on 2018/6/22.
//  Copyright © 2018年 zhanghaidi. All rights reserved.
//

#import "ViewController.h"
#import <YXAudio/YXAudio.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[YXAudioService sharedManager] startRecord];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
