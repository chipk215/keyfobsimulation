//
//  KFBAudioPlayer.m
//  KeyFobSimulator
//
//  Created by Chip Keyes on 3/5/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import "KFBAudioPlayer.h"


@implementation KFBAudioPlayer

-(id)initWithContentsOfURL:(NSURL *)url error:(NSError *__autoreleasing *)outError
{
    self = [super initWithContentsOfURL:url error:outError];
    
    return self;
}

/*
 *
 * Method Name:  play
 *
 * Description:  starts the audio player to play sound for specified duration
 *
 * Parameter(s): duration - time to play the sound
 *
 */
-(void) play:(NSTimeInterval)duration
{
    if (self.playing)
    {
        [self stop];
    }
    
    NSTimeInterval contentDuration = self.duration;
    
    
    self.numberOfLoops = (NSInteger)(duration / contentDuration) -1;
    if (self.numberOfLoops < 0) self.numberOfLoops = 0;
    [self play];
        
}



@end
