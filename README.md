Slow Motion Video Recorder for iOS
==========================

An iOS sample app for **recording 120 fps slow-motion videos** using AVFoundation. Including a wrapper class which makes the implementation much easier. Available on the **iPhone5s**. 

<img src="http://f.cl.ly/items/2S0R102A1k1v0k3z0P2R/IMG_8862_r1_c1_.jpg" width="250">


##Usage of the wrapper class

This repository includes a wrapper class "AVCaptureHelper" which makes implementing 120fps video recorder app much easier.

###1. Initialize

````
self.captureManager = [[AVCaptureManager alloc] initWithPreviewView:self.view];
self.captureManager.delegate = self;
````

###2. Start recording

````
[self.captureManager stopRecording];
````

###3. Stop recording

````
[self.captureManager stopRecording];
````


##An example for the slow motion video

<iframe src="http://player.vimeo.com/video/82064431" width="250" height="450" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe> <p><a href="http://vimeo.com/82064431">120fps Slow-Motion video recorded using AVFoundation.</a></p>

