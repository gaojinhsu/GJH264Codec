//
//  GJH264Encoder.h
//  GJH264CodecDemo
//
//  Created by Gaojin Hsu on 4/18/18.
//  Copyright © 2018 Gaojin Hsu. All rights reserved.
//

#import <Foundation/Foundation.h>
@import VideoToolbox;
@import AVFoundation;

@protocol GJH264EncoderDelegate <NSObject>
- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps spslen:(int)spslen ppslen:(int)ppslen;
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame len:(int)len;
@end

@interface GJH264Encoder: NSObject
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;
- (instancetype)initWithVideoWidth:(unsigned int)width Height:(unsigned int)height NS_DESIGNATED_INITIALIZER;
- (void)encodeImageBuffer:(CVImageBufferRef) imageBuffer;
@property (nonatomic, weak) id<GJH264EncoderDelegate> delegate;
@property (nonatomic, assign) BOOL AVCSent;
@end
