//
//  GJH264Decoder.h
//  GJH264CodecDemo
//
//  Created by Gaojin Hsu on 4/18/18.
//  Copyright © 2018 Gaojin Hsu. All rights reserved.
//

#import <Foundation/Foundation.h>
@import VideoToolbox;
@import CoreVideo;

@class GJH264Decoder;
@protocol GJH264DecoderDelegate <NSObject>

//H.264 data has been decoded and returned through this method.
- (void)GJH264Decoder:(GJH264Decoder*)decoder imageBuffer:(CVImageBufferRef) imageBufferRef width:(size_t)width height:(size_t)height;

//create an AVSampleDisplayLayer instance to receive sampleBuffer, data will be decoded and rendered automatically.
- (void)GJH264Decoder:(GJH264Decoder*)decoder sampleBufferRef:(CMSampleBufferRef) sampleBufferRef;
@end

@interface GJH264Decoder : NSObject

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;
/**
 initilize
 
 @param decodeFlag 'No' means use AVSampleDisplayLayer to decode and render, 'YES' means decode.
 @return GJH264Decoder instance
 */
- (instancetype)initWithDecodeFlag:(BOOL)decodeFlag NS_DESIGNATED_INITIALIZER;


- (void)H264FrameData:(uint8_t *_Nonnull)frame
                 size:(uint32_t)frameSize;

@property (nonatomic, weak) id<GJH264DecoderDelegate> delegate;

@end
