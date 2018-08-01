//
//  YXAudioGraph.h
//  YXAudio
//
//  Created by zhanghaidi on 2018/7/9.
//  Copyright © 2018年 zhanghaidi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YXAudioService : NSObject

+ (YXAudioService *)sharedManager;
- (void)startRecord;

@end
