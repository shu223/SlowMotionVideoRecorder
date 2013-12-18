Slow Motion Video Recorder for iOS
==========================

An iOS sample app for **recording 120 fps slow-motion videos** using AVFoundation. Including a wrapper class which makes the implementation much easier. Available on the **iPhone5s**. 

![](http://f.cl.ly/items/360a271y1G3Q2C2a3p2d/IMG_8907_r1_c1.jpg)


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


##Example for the slow motion video

![](http://f.cl.ly/items/1b3Q0h0k3k2m261s3R3n/samplemovie__.gif)

<p><a href="http://vimeo.com/82064431">See the 120fps Slo-Mo video in Vimeo 120fps.</a></p>

