//
//  AVCaptureManager.m
//  SlowMotionVideoRecorder
//
//  Created by shuichi on 12/17/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "AVCaptureManager.h"
#import <AVFoundation/AVFoundation.h>


@interface AVCaptureManager ()
<AVCaptureFileOutputRecordingDelegate>
{
    CMTime defaultVideoMaxFrameDuration;
}
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureMovieFileOutput *fileOutput;
@property (nonatomic, strong) AVCaptureDeviceFormat *defaultFormat;
@end


@implementation AVCaptureManager

- (id)initWithPreviewView:(UIView *)previewView {
    
    self = [super init];
    
    if (self) {
        
        NSError *error;
        
        self.captureSession = [[AVCaptureSession alloc] init];
        
        AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if (error) {
            NSLog(@"Video input creation failed");
            return nil;
        }
        
        if (![self.captureSession canAddInput:videoIn]) {
            NSLog(@"Video input add-to-session failed");
            return nil;
        }
        [self.captureSession addInput:videoIn];
        
        
        // save the default format
        self.defaultFormat = videoDevice.activeFormat;
        defaultVideoMaxFrameDuration = videoDevice.activeVideoMaxFrameDuration;
        
        
        AVCaptureDevice *audioDevice= [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
        [self.captureSession addInput:audioIn];
        
        self.fileOutput = [[AVCaptureMovieFileOutput alloc] init];
        [self.captureSession addOutput:self.fileOutput];
        
        
        AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        previewLayer.frame = previewView.bounds;
        previewLayer.contentsGravity = kCAGravityResizeAspectFill;
        [previewView.layer insertSublayer:previewLayer atIndex:0];
        
        [self.captureSession startRunning];
    }
    return self;
}



// =============================================================================
#pragma mark - Public

- (void)resetFormat {

    BOOL isRunning = self.captureSession.isRunning;
    
    if (isRunning) {
        [self.captureSession stopRunning];
    }

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [videoDevice lockForConfiguration:nil];
    videoDevice.activeFormat = self.defaultFormat;
    videoDevice.activeVideoMaxFrameDuration = defaultVideoMaxFrameDuration;
    [videoDevice unlockForConfiguration];

    if (isRunning) {
        [self.captureSession startRunning];
    }
}

- (void)switchFormatWithDesiredFPS:(CGFloat)desiredFPS
{
    BOOL isRunning = self.captureSession.isRunning;
    
    if (isRunning) {
        [self.captureSession stopRunning];
    }
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    // search for a Full Range video + n fps combo
    for (AVCaptureDeviceFormat *format in videoDevice.formats)
    {
        // media type
        NSString *compoundStr = [NSString stringWithFormat:@"'%@'", format.mediaType];
        
        // media sub type
        CMFormatDescriptionRef myCMFormatDescriptionRef= format.formatDescription;
        FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(myCMFormatDescriptionRef);
        BOOL fullRange = NO;
        if (mediaSubType==kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            compoundStr = [compoundStr stringByAppendingString:@"/'420v'"];
        }
        else if (mediaSubType==kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            compoundStr = [compoundStr stringByAppendingString:@"/'420f'"];
            fullRange = YES;
        }
        else {
            [compoundStr stringByAppendingString:@"'UNKNOWN'"];
        }
        
        // width, height
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(myCMFormatDescriptionRef);
        NSString *whStr = [NSString stringWithFormat:@" %ix %i", dimensions.width, dimensions.height];
        compoundStr = [compoundStr stringByAppendingString:whStr];
        
        // max framerate
        float maxFramerate = ((AVFrameRateRange*)[format.videoSupportedFrameRateRanges objectAtIndex:0]).maxFrameRate;
        NSString *maxFRStr = [NSString stringWithFormat:@", { %.0f- %.0f fps}",
                              ((AVFrameRateRange*)[format.videoSupportedFrameRateRanges objectAtIndex:0]).minFrameRate,
                              maxFramerate];
        compoundStr = [compoundStr stringByAppendingString:maxFRStr];
        
        // others
        NSString *vfofStr = [NSString stringWithFormat:@", fov: %.3f", format.videoFieldOfView];
        compoundStr = [compoundStr stringByAppendingString:vfofStr];
        
        compoundStr = [compoundStr stringByAppendingString:
                       (format.videoBinned ? @", binned" : @"")];
        
        compoundStr = [compoundStr stringByAppendingString:
                       (format.videoStabilizationSupported ? @", supports vis" : @"")];
        
        NSString *vmzfStr = [NSString stringWithFormat:@", max zoom: %.2f", format.videoMaxZoomFactor];
        compoundStr = [compoundStr stringByAppendingString:vmzfStr];
        
        NSString *vzfutStr = [NSString stringWithFormat:@" (upscales @%.2f)", format.videoZoomFactorUpscaleThreshold];
        compoundStr = [compoundStr stringByAppendingString:vzfutStr];
        
        // set to activeFormat
        if (fullRange && maxFramerate >= desiredFPS) {
            
            NSLog(@"Found %.0f fps mode: %@", desiredFPS, compoundStr);
            
            [videoDevice lockForConfiguration:nil];
            videoDevice.activeFormat = format;
            videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1, (int32_t)desiredFPS);
            [videoDevice unlockForConfiguration];
        }
    }
    
    if (isRunning) {
        [self.captureSession startRunning];
    }
}

- (void)startRecording {
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString* dateTimePrefix = [formatter stringFromDate:[NSDate date]];
    
    int fileNamePostfix = 0;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = nil;
    do
        filePath =[NSString stringWithFormat:@"/%@/%@-%i.mp4", documentsDirectory, dateTimePrefix, fileNamePostfix++];
    while ([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    
    NSURL *fileURL = [NSURL URLWithString:[@"file://" stringByAppendingString:filePath]];
    [self.fileOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
}

- (void)stopRecording {

    [self.fileOutput stopRecording];
}


// =============================================================================
#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)                 captureOutput:(AVCaptureFileOutput *)captureOutput
    didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                       fromConnections:(NSArray *)connections
{
    _isRecording = YES;
}

- (void)                 captureOutput:(AVCaptureFileOutput *)captureOutput
   didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                       fromConnections:(NSArray *)connections error:(NSError *)error
{
//    [self saveRecordedFile:outputFileURL];
    _isRecording = NO;
    
    if ([self.delegate respondsToSelector:@selector(didFinishRecordingToOutputFileAtURL:error:)]) {
        [self.delegate didFinishRecordingToOutputFileAtURL:outputFileURL error:error];
    }
}

@end
