//
//  YXAudioGraph.m
//  YXAudio
//
//  Created by zhanghaidi on 2018/7/9.
//  Copyright © 2018年 zhanghaidi. All rights reserved.
//

#import "YXAudioService.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

static CGFloat kSampleRate = 44100;

@interface YXAudioService ()
{
    AudioComponentInstance ioUnit;
    AudioBufferList recordAudioBufferList;
}

@property (nonatomic, assign) BOOL isRecording;

@end

@implementation YXAudioService

+ (YXAudioService *)sharedManager {
    static YXAudioService *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[super allocWithZone:NULL] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isRecording = NO;
    }
    return self;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [YXAudioService sharedManager];
}

- (id)copyWithZone:(struct _NSZone *)zone {
    return [YXAudioService sharedManager];
}

- (id)mutableCopyWithZone:(struct _NSZone *)zone {
    return [YXAudioService sharedManager];
}

- (void)startRecord {
    [self setupAuidoSession];
    [self setupAudioUnit];
    AudioUnitInitialize(ioUnit);
    AudioOutputUnitStart(ioUnit);
}

#pragma mark -

- (Boolean)setupAuidoSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:&error];
    if (error != nil) {
        NSLog(@"setupAudioSession : Error set AVAudioSessionCategoryOptionAllowBluetooth(%@).", error.localizedDescription);
        return false;
    }
    
    [session setMode:AVAudioSessionModeVoiceChat error:&error];
    if (error != nil) {
        NSLog (@"setupAudioSession : Error setting audio session mode AVAudioSessionModeVoiceChat(%@).", error.localizedDescription);
        return false;
    }
    
    float aBufferLength = 0.020;
    [session setPreferredIOBufferDuration:aBufferLength error:&error];
    if (error != nil) {
        NSLog (@"setupAudioSession : Error setPreferredIOBufferDuration(%@).", error.localizedDescription);
        return false;
    }
    
    //增加中断监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:session];
    
    [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error: &error];
    if (nil != error) {
        NSLog(@"AudioSession setActive error:%@", error.localizedDescription);
        return false;
    }
    
    return true;
}

- (OSStatus)setupAudioUnit {
    OSStatus status;
    
    AudioComponentDescription audioDes;
    audioDes.componentType          = kAudioUnitType_Output;
    audioDes.componentSubType       = kAudioUnitSubType_RemoteIO;
    audioDes.componentManufacturer  = kAudioUnitManufacturer_Apple;
    audioDes.componentFlags         = 0;
    audioDes.componentFlagsMask     = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDes);
    
    status = AudioComponentInstanceNew(inputComponent, &ioUnit);
    CheckOSStatus(AudioComponentInstanceNew(inputComponent, &ioUnit), "New ComponentInstance Fail");
    
    UInt32 flag = 0;
    CheckOSStatus(AudioUnitSetProperty(ioUnit,
                                        kAudioUnitProperty_ShouldAllocateBuffer,
                                        kAudioUnitScope_Output,
                                        1,
                                        &flag,
                                        sizeof(flag)), "could not set StreamFormat");

    recordAudioBufferList.mNumberBuffers = 1;
    recordAudioBufferList.mBuffers[0].mNumberChannels = 1;
    recordAudioBufferList.mBuffers[0].mDataByteSize = 2048;
    recordAudioBufferList.mBuffers[0].mData = malloc(2048);
    
    // Apply format
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = kSampleRate;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerFrame = (audioFormat.mChannelsPerFrame * audioFormat.mBitsPerChannel) / 8;
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket;
    
    CheckOSStatus(AudioUnitSetProperty(ioUnit,
                                       kAudioUnitProperty_StreamFormat,
                                       kAudioUnitScope_Output,
                                       1,
                                       &audioFormat,
                                       sizeof(audioFormat)), "could not set Output StreamFormat");
    
    
    
    CheckOSStatus(AudioUnitSetProperty(ioUnit,
                                       kAudioUnitProperty_StreamFormat,
                                       kAudioUnitScope_Input,
                                       0,
                                       &audioFormat,
                                       sizeof(audioFormat)), "could not set Input StreamFormat");
    
    
    
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = recordCallbackFunc;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    
    CheckOSStatus(AudioUnitSetProperty(ioUnit,
                                       kAudioOutputUnitProperty_SetInputCallback,
                                       kAudioUnitScope_Global,
                                       1,
                                       &recordCallback,
                                       sizeof(recordCallback)), "");
    
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = playbackCallbackFunc;
    playCallback.inputProcRefCon = (__bridge void *)self;
    
    CheckOSStatus(AudioUnitSetProperty(ioUnit,
                                       kAudioUnitProperty_SetRenderCallback,
                                       kAudioUnitScope_Global,
                                       0,
                                       &playCallback,
                                       sizeof(playCallback)), "");
    
    flag = 1;
    CheckOSStatus(AudioUnitSetProperty(ioUnit,
                                       kAudioOutputUnitProperty_EnableIO,
                                       kAudioUnitScope_Input,
                                       1,
                                       &flag,
                                       sizeof(flag)), "");
    
    // Enable IO for playback
    flag = 1;
    
    CheckOSStatus(AudioUnitSetProperty(ioUnit,
                                       kAudioOutputUnitProperty_EnableIO,
                                       kAudioUnitScope_Output,
                                       0,
                                       &flag,
                                       sizeof(flag)), "");
    
    return true;
}

- (AudioBufferList)getBufferList:(UInt32)inNumberFrames {
    return recordAudioBufferList;
}

- (NSData *)getPlayFrame:(UInt32)dataByteSize {
    AudioBuffer *buffer = recordAudioBufferList.mBuffers[0].mData;
    NSData *data = [[NSData alloc] initWithBytes:buffer length:dataByteSize];
    return data;
}

static OSStatus recordCallbackFunc(void *inRefCon,
                                   AudioUnitRenderActionFlags *ioActionFlags,
                                   const AudioTimeStamp *inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList *ioData) {
    
    YXAudioService *this = (__bridge YXAudioService *)inRefCon;
    
    OSStatus err = noErr;
    if (this.isRecording == NO){
        @autoreleasepool {
            AudioBufferList bufList = [this getBufferList:inNumberFrames];
            err = AudioUnitRender(this->ioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufList);
            if (err) {
                printf("AudioUnitRender error code = %d", err);
            } else {
                AudioBuffer buffer = bufList.mBuffers[0];
                NSData *pcmBlock = [NSData dataWithBytes:buffer.mData length:buffer.mDataByteSize];
                NSLog(@"pcm = %lu", pcmBlock.length);
            }
        }
    }
    
    return err;
}

static OSStatus playbackCallbackFunc(void *inRefCon,
                                     AudioUnitRenderActionFlags *ioActionFlags,
                                     const AudioTimeStamp *inTimeStamp,
                                     UInt32 inBusNumber,
                                     UInt32 inNumberFrames,
                                     AudioBufferList *ioData){
    
    YXAudioService *this = (__bridge YXAudioService *)inRefCon;
    OSStatus err = noErr;
    if (this.isRecording == NO) {
        for (int i = 0; i < ioData -> mNumberBuffers; i++) {
            @autoreleasepool {
                AudioBuffer buffer = ioData->mBuffers[i];
                NSData *pcmBlock = [this getPlayFrame:buffer.mDataByteSize];
                if (pcmBlock && pcmBlock.length) {
                    UInt32 size = (UInt32)MIN(buffer.mDataByteSize, [pcmBlock length]);
                    memcpy(buffer.mData, [pcmBlock bytes], size);
                    buffer.mDataByteSize = size;
                } else {
                    buffer.mDataByteSize = 0;
                    *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
                }
            }
        }
    }
    return err;
}

static void CheckOSStatus(OSStatus result, const char *operation) {
    if (result == noErr) {
        return;
    }
    
    char errorString[20];
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(result);
    if (isprint(errorString[1]) &&
        isprint(errorString[2]) &&
        isprint(errorString[3]) &&
        isprint(errorString[4])) {
        
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else {
        sprintf(errorString,"%d",(int)result);
    }
    
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
}

#pragma mark - Notificaiton

- (void)handleInterruption:(NSNotification *)notification {
    UInt8 theInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    if (theInterruptionType == AVAudioSessionInterruptionTypeBegan) {
     
    } else if (theInterruptionType == AVAudioSessionInterruptionTypeEnded) {
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        
        if (nil != error) NSLog(@"AVAudioSession set active failed with error: %@", error);
    }
}


@end
