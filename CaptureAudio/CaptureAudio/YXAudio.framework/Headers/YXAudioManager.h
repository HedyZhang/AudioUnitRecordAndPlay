//
//  AUGraphManager.h
//  CaptureAudio
//
//  Created by zhanghaidi on 2018/7/2.
//  Copyright © 2018年 zhanghaidi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YXAudioManager : NSObject

@property (nonatomic, assign) int globalRecordedBytes;
@property (nonatomic, assign) int globalPlayedBytes;
@property (nonatomic, assign) int globalReceivedBytes;
@property (nonatomic, assign) int globalSentBytes;
@property (nonatomic, assign) int globalReceivedPackages;
@property (nonatomic, assign) int globalSentPackages;
@property (nonatomic, assign) int globalReceivedDuplicatePackages;

+ (YXAudioManager *)sharedManager;

@end
