//
//  AudioManager.m
//  CaptureAudio
//
//  Created by zhanghaidi on 2018/6/22.
//  Copyright © 2018年 zhanghaidi. All rights reserved.
//

#import "AudioManager.h"

@import AVFoundation;
@import AudioToolbox;
@import CoreAudio;

@interface AudioManager ()

@property (nonatomic, assign) AudioComponentInstance audioUnit;
@property (nonatomic, assign) AudioBufferList *buffList;

@end

@implementation AudioManager

+ (AudioManager *)sharedAudioManager{
    static AudioManager *sharedAudioManager;
    @synchronized(self)
    {
        if (!sharedAudioManager) {
            sharedAudioManager = [[AudioManager alloc] init];
        }
        return sharedAudioManager;
    }
}

- (void)initRemoteIO {
    AudioUnitInitialize(_audioUnit);
    [self setupAuidoSession];
    
    [self initAudioComponent];
    
    [self initBuffer];
    
    [self initFormat];
    
    [self initAudioProperty];
    
    [self initRecordeCallback];
    
    [self initPlayCallback];
}

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
    
    //远程终端改变监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:session];
    
    [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    if (nil != error) {
        NSLog(@"AudioSession setActive error:%@", error.localizedDescription);
        return false;
    }
    
    return true;
}

- (void)handleRouteChange:(NSNotification *)notification {
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *previousRoute = [mySession currentRoute];
    AVAudioSessionPortDescription *previousOutput = previousRoute.outputs[0];
    NSString *portType = previousOutput.portType;
    if ([portType isEqualToString:AVAudioSessionPortBuiltInReceiver]) {
        //如果是听筒那么重置为扬声器
        NSError *audioSessionError = nil;
        if (![mySession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&audioSessionError]) {
            NSLog (@"setupAudioSession : Error set AVAudioSessionPortOverrideSpeaker (%@).",audioSessionError);
        }
    }
}

- (void)initBuffer {
    UInt32 flag = 0;
    AudioUnitSetProperty(_audioUnit,
                         kAudioUnitProperty_ShouldAllocateBuffer,
                         kAudioUnitScope_Output,
                         1,
                         &flag,
                         sizeof(flag));
    
    self.buffList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    _buffList->mNumberBuffers = 1;
    _buffList->mBuffers[0].mNumberChannels = 2;
    _buffList->mBuffers[0].mDataByteSize = 2048;
    _buffList->mBuffers[0].mData = malloc(2048);
}

- (void)initAudioComponent {
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &_audioUnit);
}

- (void)initFormat {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 8000;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    
    AudioUnitSetProperty(_audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         1,
                         &audioFormat,
                         sizeof(audioFormat));
    
    AudioUnitSetProperty(_audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &audioFormat,
                         sizeof(audioFormat));
}


- (void)initRecordeCallback {
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(_audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Global,
                         1,
                         &recordCallback,
                         sizeof(recordCallback));
}

- (void)initPlayCallback {
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(_audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Global,
                         0,
                         &playCallback,
                         sizeof(playCallback));
}

- (void)initAudioProperty {
    UInt32 flag = 1;
    AudioUnitSetProperty(_audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         1,
                         &flag,
                         sizeof(flag));
    AudioUnitSetProperty(_audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Output,
                         0,
                         &flag,
                         sizeof(flag));
    
}

#pragma mark - callback function

static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    NSLog(@"inNumberFrames = %d", inNumberFrames);
    AudioComponentInstance audioUnit = [AudioManager sharedAudioManager].audioUnit;
    AudioBufferList *buffList = [AudioManager sharedAudioManager].buffList;
    AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, buffList);
    
    NSLog(@"size1 = %d", buffList->mBuffers[0].mDataByteSize);


    return noErr;
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    NSLog(@"size2 = %d", ioData->mBuffers[0].mDataByteSize);
    
    memcpy(ioData->mBuffers[0].mData, [AudioManager sharedAudioManager].buffList->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
//    AudioComponentInstance audioUnit = [AudioManager sharedAudioManager].audioUnit;
//    AudioBufferList *buffList = [AudioManager sharedAudioManager].buffList;
//    AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, buffList);
    return noErr;
}

- (void)startRecorder {
    [self initRemoteIO];
    AudioOutputUnitStart(_audioUnit);
}


@end
