//
//  GJH264Encoder.m
//  GJH264CodecDemo
//
//  Created by Gaojin Hsu on 4/18/18.
//  Copyright © 2018 Gaojin Hsu. All rights reserved.
//

#import "GJH264Encoder.h"
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer ){
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    GJH264Encoder* encoder = (__bridge GJH264Encoder*)outputCallbackRefCon;
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    if (keyframe) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr) {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr) {
                // Found pps
                if ([encoder.delegate respondsToSelector:@selector(gotSpsPps:pps:spslen:ppslen:)]  &&  !encoder.AVCSent) {
                    [encoder.delegate gotSpsPps:[NSData dataWithBytes:sparameterSet length:sparameterSetSize] pps:[NSData dataWithBytes:pparameterSet length:pparameterSetSize] spslen:(int)sparameterSetSize ppslen:(int)pparameterSetSize];
                    encoder.AVCSent = YES;//avc只发一次
                }
            }
        }
        
    }
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            if ([encoder.delegate respondsToSelector:@selector(gotEncodedData:isKeyFrame:len:)]) {
                [encoder.delegate gotEncodedData:data isKeyFrame:keyframe len:NALUnitLength];
            }
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

@interface GJH264Encoder ()
@property (nonatomic, assign) unsigned long frameCount;
@property (nonatomic, assign) unsigned int videoWidth;
@property (nonatomic, assign) unsigned int videoHeight;
@property (nonatomic, assign) VTCompressionSessionRef encodingSession;
@end
@implementation GJH264Encoder {
    dispatch_queue_t _videoEncodingQueue;
}

- (instancetype)initWithVideoWidth:(unsigned int)width Height:(unsigned int)height {
    self = [super init];
    if (self) {
        NSLog(@"h264encoder initWithVideoWidth:%d videoHeight:%d", width, height);
        _videoEncodingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _videoWidth = width;
        _videoHeight = height;
    }
    return self;
}

- (void)dealloc {
    dispatch_sync(_videoEncodingQueue, ^{
        if (self.encodingSession) {
            VTCompressionSessionInvalidate (self.encodingSession);
            CFRelease(self.encodingSession);
            self.encodingSession = NULL;
        }
    });
}

- (void)encodeImageBuffer:(CVImageBufferRef) imageBuffer {
    dispatch_sync(_videoEncodingQueue, ^{
        self.frameCount++;
        // Create properties
        CMTime presentationTimeStamp = CMTimeMake(self.frameCount, 1000);
        //CMTime duration = CMTimeMake(1, DURATION);
        VTEncodeInfoFlags flags;
        // Pass it to the encoder
        if (!self.encodingSession) {
            [self _createSession];
        }
        OSStatus statusCode = VTCompressionSessionEncodeFrame(self.encodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL,
                                                              NULL,
                                                              &flags);
        // Check for error
        if (statusCode != noErr) {
            NSLog(@"encode frame error: %d", (int)statusCode);
            [self _createSession];
            return;
        }
    });
}

- (void)_createSession {
    if (_encodingSession) {
        VTCompressionSessionInvalidate(_encodingSession);
        CFRelease(_encodingSession);
        _encodingSession = NULL;
    }
    OSStatus status = VTCompressionSessionCreate(NULL, _videoWidth, _videoHeight, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &_encodingSession);
    if (status != 0){
        NSLog(@"create h264 encoding session failed, width: %d height: %d", _videoWidth, _videoHeight);
        return ;
    }
    // Set the properties
    VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
    
    VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(400 * 1024));
    VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(500 * 1024/ 8), @1]);
    VTSessionSetProperty(_encodingSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,(__bridge CFTypeRef _Nonnull)(@0.08));
    
    // Tell the encoder to start encoding
    VTCompressionSessionPrepareToEncodeFrames(_encodingSession);
}

@end
