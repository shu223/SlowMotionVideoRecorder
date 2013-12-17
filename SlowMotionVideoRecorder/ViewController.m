//
//  ViewController.m
//  SlowMotionVideoRecorder
//
//  Created by shuichi on 12/17/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "SVProgressHUD.h"


@interface ViewController ()
<AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
{
    BOOL isRecording;
    BOOL isNeededToSave;
    NSTimeInterval startTime;
    CMTime defaultVideoMaxFrameDuration;
}
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureMovieFileOutput *fileOutput;
@property (nonatomic, strong) AVCaptureDeviceFormat *defaultFormat;
@property (nonatomic, assign) NSTimer *timer;

@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UISegmentedControl *fpsControl;
@property (nonatomic, weak) IBOutlet UIButton *retakeBtn;
@property (nonatomic, weak) IBOutlet UIButton *stopBtn;
@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.retakeBtn.hidden = YES;
    self.stopBtn.hidden = YES;
    self.fpsControl.hidden = NO;
    
    [self initVideo];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


// =============================================================================
#pragma mark - Private

- (void)initVideo {
    
    NSError *error;
    
    self.captureSession = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    
    if (error) {
        
        NSLog(@"Video input creation failed");
        return;
    }
    
    if ([self.captureSession canAddInput:videoIn]) {
        [self.captureSession addInput:videoIn];
    }
    else {
        NSLog(@"Video input add-to-session failed");
    }
    
    
    // save the default format
    self.defaultFormat = videoDevice.activeFormat;
    defaultVideoMaxFrameDuration = videoDevice.activeVideoMaxFrameDuration;
    
    
    AVCaptureDevice *audioDevice= [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    [self.captureSession addInput:audioIn];
    
    self.fileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [self.captureSession addOutput:self.fileOutput];
    
    
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    previewLayer.frame = self.view.bounds;
    previewLayer.contentsGravity = kCAGravityResizeAspectFill;
	[self.view.layer insertSublayer:previewLayer atIndex:0];
    
    [self.captureSession startRunning];
}

- (void)setupFormatForVideoDevice:(AVCaptureDevice *)videoDevice
                       desiredFPS:(CGFloat)desiredFPS
{
    // search for a Full Range video + n fps combo
    for (AVCaptureDeviceFormat *format in videoDevice.formats)
    {
        NSString *compoundStr = @"";
        
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@"'%@'", format.mediaType]];
        
        CMFormatDescriptionRef myCMFormatDescriptionRef= format.formatDescription;
        FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(myCMFormatDescriptionRef);
        BOOL fullRange = NO;
        if (mediaSubType==kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
            compoundStr = [compoundStr stringByAppendingString:@"/'420v'"];
        else if (mediaSubType==kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        {
            compoundStr = [compoundStr stringByAppendingString:@"/'420f'"];
            fullRange = YES;
        }
        else [compoundStr stringByAppendingString:@"'UNKNOWN'"];
        
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(myCMFormatDescriptionRef);
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@" %ix %i", dimensions.width, dimensions.height]];
        
        float maxFramerate = ((AVFrameRateRange*)[format.videoSupportedFrameRateRanges objectAtIndex:0]).maxFrameRate;
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@", { %.0f- %.0f fps}", ((AVFrameRateRange*)[format.videoSupportedFrameRateRanges objectAtIndex:0]).minFrameRate,
                                                            maxFramerate]];
        
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@", fov: %.3f", format.videoFieldOfView]];
        compoundStr = [compoundStr stringByAppendingString:
                       (format.videoBinned ? @", binned" : @"")];
        
        compoundStr = [compoundStr stringByAppendingString:
                       (format.videoStabilizationSupported ? @", supports vis" : @"")];
        
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@", max zoom: %.2f", format.videoMaxZoomFactor]];
        
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@" (upscales @%.2f)", format.videoZoomFactorUpscaleThreshold]];
        
        if (fullRange && maxFramerate >= desiredFPS)
        {
            NSLog(@"Found %.0f fps mode: %@", desiredFPS, compoundStr);
            [videoDevice lockForConfiguration:nil];
            videoDevice.activeFormat = format;
            videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1, (int32_t)desiredFPS);
            [videoDevice unlockForConfiguration];
        }
    }
}

- (void)startVideoRecording {
    
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

- (void)saveRecordedFile:(NSURL *)recordedFile {
    
    if (!isNeededToSave) {
        return;
    }
    
    [SVProgressHUD showWithStatus:@"Saving..."
                         maskType:SVProgressHUDMaskTypeGradient];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary writeVideoAtPathToSavedPhotosAlbum:recordedFile
                                         completionBlock:
         ^(NSURL *assetURL, NSError *error) {
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 [SVProgressHUD dismiss];
                 
                 NSString *title;
                 NSString *message;
                 
                 if (error != nil) {
                     
                     title = @"Failed to save video";
                     message = [error localizedDescription];
                 }
                 else {
                     title = @"Saved!";
                     message = nil;
                 }
                 
                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                                 message:message
                                                                delegate:nil
                                                       cancelButtonTitle:@"OK"
                                                       otherButtonTitles:nil];
                 [alert show];
             });
         }];
    });
}



// =============================================================================
#pragma mark - Timer Handler

- (void)timerHandler:(NSTimer *)timer {
    
    NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval recorded = current - startTime;
    self.statusLabel.text = [NSString stringWithFormat:@"Recording: %.2f sec", recorded];
}


// =============================================================================
#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)                 captureOutput:(AVCaptureFileOutput *)captureOutput
    didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                       fromConnections:(NSArray *)connections
{
}

- (void)                 captureOutput:(AVCaptureFileOutput *)captureOutput
   didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                       fromConnections:(NSArray *)connections error:(NSError *)error
{
    [self saveRecordedFile:outputFileURL];
    isRecording = NO;
}






// =============================================================================
#pragma mark - IBAction

- (IBAction)startButtonTapped:(id)sender {
    
    if (!isRecording) {
        
        
        
        NSLog(@"==== STARTING RECORDING ====");
        
        isRecording = YES;
        
        self.stopBtn.hidden = NO;
        self.retakeBtn.hidden = NO;
        self.fpsControl.hidden = YES;
        
        [self startVideoRecording];
    }
    
    // 時間経過取得用
    startTime = [[NSDate date] timeIntervalSince1970];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01
                                                  target:self
                                                selector:@selector(timerHandler:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (IBAction)stopButtonTapped:(id)sender {
    
    isNeededToSave = YES;
    [self.fileOutput stopRecording];
    
    [self.timer invalidate];
    self.timer = nil;
    
    self.stopBtn.hidden = YES;
    self.retakeBtn.hidden = YES;
    self.fpsControl.hidden = NO;
}

- (IBAction)retakeButtonTapped:(id)sender {
    
    isNeededToSave = NO;
    [self.fileOutput stopRecording];

    [self.timer invalidate];
    self.timer = nil;
    
    self.statusLabel.text = nil;
}

- (IBAction)fpsChanged:(UISegmentedControl *)sender {
    
    // Switch the FPS
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    CGFloat desiredFps;
    switch (self.fpsControl.selectedSegmentIndex) {
        case 0:
        default:
        {
            [videoDevice lockForConfiguration:nil];
            videoDevice.activeFormat = self.defaultFormat;
            videoDevice.activeVideoMaxFrameDuration = defaultVideoMaxFrameDuration;
            [videoDevice unlockForConfiguration];
            
            return;
        }
        case 1:
            desiredFps = 60.0;
            break;
        case 2:
            desiredFps = 120.0;
            break;
    }
    
    
    [SVProgressHUD showWithStatus:@"Switching..."
                         maskType:SVProgressHUDMaskTypeGradient];
    
    [self.captureSession stopRunning];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        
        [self setupFormatForVideoDevice:videoDevice
                             desiredFPS:desiredFps];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [SVProgressHUD dismiss];
            
            [self.captureSession startRunning];
        });
    });
}

@end
