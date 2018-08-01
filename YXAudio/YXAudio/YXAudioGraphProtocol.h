//
//  YXAudioGraphProtocol.h
//  YXAudio
//
//  Created by zhanghaidi on 2018/7/9.
//  Copyright © 2018年 zhanghaidi. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol YXAudioGraphDelegate<NSObject>

@optional
- (void)handleInterruption:(NSInteger)interruptionType;
- (void)routeChange:(NSString *)portName;

@end
