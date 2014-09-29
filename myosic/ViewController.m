//
//  ViewController.m
//  Example
//
//  Created by Kevin Renskers on 03-10-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import "ViewController.h"
#import <MyoKit/MyoKit.h>
#import "GVMusicPlayerController.h"
#import "NSString+TimeToString.h"

@interface ViewController () <GVMusicPlayerControllerDelegate>
@property (weak, nonatomic) IBOutlet UIView *viewToBlur1;
@property (weak, nonatomic) IBOutlet UIView *viewToBlur2;
@property (weak, nonatomic) IBOutlet UILabel *songLabel;
@property (weak, nonatomic) IBOutlet UILabel *artistLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;
@property (weak, nonatomic) IBOutlet UISlider *volumeSlider;
@property (weak, nonatomic) IBOutlet UILabel *trackCurrentPlaybackTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *trackLengthLabel;
@property (weak, nonatomic) IBOutlet UIButton *repeatButton;
@property (weak, nonatomic) IBOutlet UIButton *shuffleButton;
@property (weak, nonatomic) IBOutlet UIButton *myoButton;
@property (nonatomic) BOOL isVoluming;
@property (strong, nonatomic) NSTimer *timer;
@property (nonatomic, retain) NSTimer *autoLockTimer;
@property BOOL panningProgress;
@property BOOL panningVolume;

@property BOOL locked;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // locked the myo by default
    self.locked = YES;

    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timedJob) userInfo:nil repeats:YES];
    [self.timer fire];
    
    // Myo Notifications
    // a myo connects
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didConnectMyo:) name:TLMMyoDidReceiveArmRecognizedEventNotification object:nil];
    // a myo disconnects
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didDisconnectMyo:) name:TLMHubDidConnectDeviceNotification object:nil];
    // receive a pose
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceivePoseChange:) name:TLMMyoDidReceivePoseChangedNotification object:nil];
    // receive a snap
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveSnap:) name:@"TLMMyoDidReceiveSnapGestureNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveGyroscopeEvent:) name:TLMMyoDidReceiveGyroscopeEventNotification object:nil];
    
    // launch the player
#if !(TARGET_IPHONE_SIMULATOR)
    MPMediaQuery *query = [MPMediaQuery songsQuery];
    [[GVMusicPlayerController sharedInstance] setQueueWithQuery:query];
    [[GVMusicPlayerController sharedInstance] play];
    [GVMusicPlayerController sharedInstance].shuffleMode = MPMusicShuffleModeSongs;
    self.shuffleButton.selected = YES;
#endif

    // blur the views
    self.viewToBlur1.backgroundColor = [UIColor clearColor];
    UIToolbar* bgToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.viewToBlur1.frame.origin.y-80, self.viewToBlur1.frame.size.width, self.viewToBlur1.frame.size.height)];
    bgToolbar.barStyle = UIBarStyleBlackTranslucent;
    [self.viewToBlur1.superview insertSubview:bgToolbar belowSubview:self.viewToBlur1];
    self.viewToBlur2.backgroundColor = [UIColor clearColor];
    UIToolbar* bgToolbar2 = [[UIToolbar alloc] initWithFrame:self.viewToBlur2.frame];
    bgToolbar2.barStyle = UIBarStyleBlackTranslucent;
    [self.viewToBlur2.superview insertSubview:bgToolbar2 belowSubview:self.viewToBlur2];
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];
    [[GVMusicPlayerController sharedInstance] addDelegate:self];
    
    self.navigationController.navigationBarHidden = YES;
    
    if ([[[TLMHub sharedHub] myoDevices] count] == 0) {
        self.myoButton.selected = NO;
    } else {
        self.myoButton.selected = YES;
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [[GVMusicPlayerController sharedInstance] removeDelegate:self];
    [super viewDidDisappear:animated];
}

- (void)timedJob {
    if (!self.panningProgress) {
        self.progressSlider.value = [GVMusicPlayerController sharedInstance].currentPlaybackTime;
        self.trackCurrentPlaybackTimeLabel.text = [NSString stringFromTime:[GVMusicPlayerController sharedInstance].currentPlaybackTime];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.shuffleButton.selected = ([GVMusicPlayerController sharedInstance].shuffleMode != MPMusicShuffleModeOff);
    [self setCorrectRepeatButtomImage];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    [[TLMHub sharedHub] attachToAdjacent];
    
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
    [super viewWillDisappear:animated];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark - Catch remote control events, forward to the music player

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    [[GVMusicPlayerController sharedInstance] remoteControlReceivedWithEvent:receivedEvent];
}

#pragma mark - Myo delegate

- (void)didConnectMyo: (NSNotification *)notification {
    self.myoButton.selected = YES;
}

- (void)didDisconnectMyo: (NSNotification *)notification {
    self.myoButton.selected = NO;
}

- (void)didReceivePoseChange:(NSNotification*)notification {
    TLMPose *pose = notification.userInfo[kTLMKeyPose];
    NSLog(@"%d", pose.type);
    
    if (!self.locked && self.isVoluming && pose.type == TLMPoseTypeRest) {
        self.isVoluming = NO;
        [self resetAutolock];
    }
    else if (self.isVoluming) {
        return;
    }
    
    switch (pose.type) {
        case TLMPoseTypeFist:
            if (!self.locked) {
                self.isVoluming = YES;
                [self.autoLockTimer invalidate];
            }
            break;
        case TLMPoseTypeFingersSpread:
            if (!self.locked) {
                [self playButtonPressed];
                [self resetAutolock];
            }
            break;
        case TLMPoseTypeWaveOut:
            if (!self.locked) {
                [self nextButtonPressed];
                [self resetAutolock];
            }
            break;
        case TLMPoseTypeWaveIn:
            if (!self.locked) {
                [self prevButtonPressed];
                [self resetAutolock];
            }
            break;
        case TLMPoseTypeThumbToPinky:
            [self lockOrUnlock];
            break;
        case TLMPoseTypeUnknown:
        case TLMPoseTypeRest:
        default:
            break;
    }
}

-(void)didReceiveGyroscopeEvent:(NSNotification *)notification {
    TLMGyroscopeEvent *event = notification.userInfo[kTLMKeyGyroscopeEvent];
    GLKVector3 v = event.vector;
    if (self.isVoluming) {
        NSLog(@"%f", v.x);
        [GVMusicPlayerController sharedInstance].volume -= v.x / 500;
    }
}

- (void)didReceiveSnap:(NSNotification*)notification {
    [self lockOrUnlock];
}

- (void)shortVibration {
    [[[TLMHub sharedHub] myoDevices][0] vibrateWithLength:TLMVibrationLengthShort];
}

-(void)lock {
    if (!self.locked) {
        [self shortVibration];
    }
    self.locked = YES;
    NSLog(@"%@", self.locked?@"locked":@"unlocked");
}

-(void)lockOrUnlock {
    self.locked = !self.locked;
    if (self.locked) {
        [self shortVibration];
        [self.autoLockTimer  invalidate];
    } else {
        [self shortVibration];
        [[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(shortVibration) userInfo:nil repeats:NO] fire];
        [self resetAutolock];
    }
    NSLog(@"%@", self.locked?@"locked":@"unlocked");
}

#pragma mark - Music player actions

- (IBAction)playButtonPressed {
    if ([GVMusicPlayerController sharedInstance].playbackState == MPMusicPlaybackStatePlaying) {
        [[GVMusicPlayerController sharedInstance] pause];
    } else {
        [[GVMusicPlayerController sharedInstance] play];
    }
}

- (IBAction)prevButtonPressed {
    [[GVMusicPlayerController sharedInstance] skipToPreviousItem];
}

- (IBAction)nextButtonPressed {
    [[GVMusicPlayerController sharedInstance] skipToNextItem];
}

- (IBAction)volumeChanged:(UISlider *)sender {
    self.panningVolume = YES;
    [GVMusicPlayerController sharedInstance].volume = sender.value;
}

- (IBAction)volumeEnd {
    self.panningVolume = NO;
}

- (IBAction)progressChanged:(UISlider *)sender {
    // While dragging the progress slider around, we change the time label,
    // but we're not actually changing the playback time yet.
    self.panningProgress = YES;
    self.trackCurrentPlaybackTimeLabel.text = [NSString stringFromTime:sender.value];
}

- (IBAction)progressEnd {
    // Only when dragging is done, we change the playback time.
    [GVMusicPlayerController sharedInstance].currentPlaybackTime = self.progressSlider.value;
    self.panningProgress = NO;
}

- (IBAction)shuffleButtonPressed {
    self.shuffleButton.selected = !self.shuffleButton.selected;

    if (self.shuffleButton.selected) {
        [GVMusicPlayerController sharedInstance].shuffleMode = MPMusicShuffleModeSongs;
    } else {
        [GVMusicPlayerController sharedInstance].shuffleMode = MPMusicShuffleModeOff;
    }
}

- (IBAction)repeatButtonPressed {
    switch ([GVMusicPlayerController sharedInstance].repeatMode) {
        case MPMusicRepeatModeAll:
            // From all to one
            [GVMusicPlayerController sharedInstance].repeatMode = MPMusicRepeatModeOne;
            break;

        case MPMusicRepeatModeOne:
            // From one to none
            [GVMusicPlayerController sharedInstance].repeatMode = MPMusicRepeatModeNone;
            break;

        case MPMusicRepeatModeNone:
            // From none to all
            [GVMusicPlayerController sharedInstance].repeatMode = MPMusicRepeatModeAll;
            break;

        default:
            [GVMusicPlayerController sharedInstance].repeatMode = MPMusicRepeatModeAll;
            break;
    }

    [self setCorrectRepeatButtomImage];
}

- (void)setCorrectRepeatButtomImage {
    NSString *imageName;

    switch ([GVMusicPlayerController sharedInstance].repeatMode) {
        case MPMusicRepeatModeAll:
            imageName = @"repeat_all";
            break;

        case MPMusicRepeatModeOne:
            imageName = @"repeat_one";
            break;

        case MPMusicRepeatModeNone:
            imageName = @"repeat_off";
            break;

        default:
            imageName = @"repeat_off";
            break;
    }

    [self.repeatButton setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
}

#pragma mark - AVMusicPlayerControllerDelegate

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer playbackStateChanged:(MPMusicPlaybackState)playbackState previousPlaybackState:(MPMusicPlaybackState)previousPlaybackState {
    self.playPauseButton.selected = (playbackState == MPMusicPlaybackStatePlaying);
}

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer trackDidChange:(MPMediaItem *)nowPlayingItem previousTrack:(MPMediaItem *)previousTrack {

    // Time labels
    NSTimeInterval trackLength = [[nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
    self.trackLengthLabel.text = [NSString stringFromTime:trackLength];
    self.progressSlider.value = 0;
    self.progressSlider.maximumValue = trackLength;

    // Labels
    self.songLabel.text = [nowPlayingItem valueForProperty:MPMediaItemPropertyTitle];
    self.artistLabel.text = [nowPlayingItem valueForProperty:MPMediaItemPropertyArtist];

    // Artwork
    MPMediaItemArtwork *artwork = [nowPlayingItem valueForProperty:MPMediaItemPropertyArtwork];
    if (artwork != nil) {
        self.imageView.image = [artwork imageWithSize:self.imageView.frame.size];
    }
}

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer endOfQueueReached:(MPMediaItem *)lastTrack {
}

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer volumeChanged:(float)volume {
    if (!self.panningVolume) {
        self.volumeSlider.value = volume;
    }
}

#pragma mark - autolock

-(void)resetAutolock {
    [self.autoLockTimer invalidate];
    self.autoLockTimer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(lock) userInfo:nil repeats:NO];
    //[self.autoLockTimer fire];
}

@end
