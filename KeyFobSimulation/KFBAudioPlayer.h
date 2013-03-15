//
//  KFBAudioPlayer.h
//  KeyFobSimulator
//
//  Created by Chip Keyes on 3/5/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface KFBAudioPlayer : AVAudioPlayer


/*
 *
 * Method Name:  play
 *
 * Description:  starts the audio player to play sound for specified duration
 *
 * Parameter(s): duration - time to play the sound
 *
 */
-(void)play: (NSTimeInterval)duration;

-(id)initWithContentsOfURL:(NSURL *)url error:(NSError *__autoreleasing *)outError;


@end
