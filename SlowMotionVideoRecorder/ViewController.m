//
//  ViewController.m
//  SlowMotionVideoRecorder
//
//  Created by shuichi on 12/17/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "ViewController.h"
#import "SVProgressHUD.h"
#import "AVCaptureManager.h"
#import <AssetsLibrary/AssetsLibrary.h>


@interface ViewController ()
<AVCaptureManagerDelegate>
{
    NSTimeInterval startTime;
    BOOL isNeededToSave;
}
@property (nonatomic, strong) AVCaptureManager *captureManager;
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
    
    self.captureManager = [[AVCaptureManager alloc] initWithPreviewView:self.view];
    self.captureManager.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


// =============================================================================
#pragma mark - Private


- (void)saveRecordedFile:(NSURL *)recordedFile {
    
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
#pragma mark - AVCaptureManagerDeleagte

- (void)didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL error:(NSError *)error {
    
    if (error) {
        NSLog(@"error:%@", error);
        return;
    }
    
    if (!isNeededToSave) {
        return;
    }
    
    [self saveRecordedFile:outputFileURL];
}


// =============================================================================
#pragma mark - IBAction

- (IBAction)startButtonTapped:(id)sender {
    
    if (!self.captureManager.isRecording) {
        
        self.stopBtn.hidden = NO;
        self.retakeBtn.hidden = NO;
        self.fpsControl.hidden = YES;
        
        [self.captureManager startRecording];
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
    [self.captureManager stopRecording];
    
    [self.timer invalidate];
    self.timer = nil;
    
    self.stopBtn.hidden = YES;
    self.retakeBtn.hidden = YES;
    self.fpsControl.hidden = NO;
}

- (IBAction)retakeButtonTapped:(id)sender {
    
    isNeededToSave = NO;
    [self.captureManager stopRecording];

    [self.timer invalidate];
    self.timer = nil;
    
    self.statusLabel.text = nil;
}

- (IBAction)fpsChanged:(UISegmentedControl *)sender {
    
    // Switch FPS
    
    CGFloat desiredFps = 0.0;;
    switch (self.fpsControl.selectedSegmentIndex) {
        case 0:
        default:
        {
            break;
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
        
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        
        if (desiredFps > 0.0) {
            [self.captureManager switchFormatWithDesiredFPS:desiredFps];
        }
        else {
            [self.captureManager resetFormat];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [SVProgressHUD dismiss];
        });
    });
}

@end
