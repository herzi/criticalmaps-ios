//
//  PLChatModel.m
//  CriticalMaps
//
//  Created by Norman Sander on 19.02.15.
//  Copyright (c) 2015 Pokus Labs. All rights reserved.
//

#import "PLChatModel.h"
#import "PLUtils.h"
#import "PLConstants.h"
#import "PLChatObject.h"
#import <NSString+Hashes.h>

@interface PLChatModel()

@property(nonatomic, strong) PLDataModel *data;

@end

@implementation PLChatModel

+ (id)sharedManager {
    static PLChatModel *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id)init {
    if (self = [super init]) {
        _data = [PLDataModel sharedManager];
        _messages = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)collectMessage:(NSString*) text {
    NSString *timestamp = [PLUtils getTimestamp];
    NSString *messageId = [NSString stringWithFormat:@"%@%@", _data.uid, timestamp];
    NSString *messageIdHashed = [messageId md5];
    
    PLChatObject *co = [[PLChatObject alloc] init];
    co.identifier = messageIdHashed;
    co.timestamp = timestamp;
    co.text = text;
    co.isActive = NO;
    
    [_messages addObject:co];
    [_data request];
    
    // notify view
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationChatMessagesReceived object:self];
    
}

- (void)addMessages: (NSDictionary*)messages {
    // Iterate obtained messages
    for(id key in messages){
        
        NSDictionary *message = [messages objectForKey:key];
        PLChatObject *co = [self getMessage:key];
        
        if(co){
            co.isActive = YES;
            co.timestamp = [NSString stringWithFormat:@"%lu", (long)[message objectForKey:@"timestamp"]];
        }else{
            // create chat object
            PLChatObject *co = [[PLChatObject alloc] init];
            co.identifier = key;
            co.timestamp = [NSString stringWithFormat:@"%lu", (long)[message objectForKey:@"timestamp"]];
            co.text = [[[message objectForKey:@"message"]
                        stringByReplacingOccurrencesOfString:@"+" withString:@" "]
                        stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            co.isActive = YES;
            
            // fill dict
            [_messages addObject:co];
        }
    }
    
    // Iterate existing messages and clear old
    for (int i = 0; i < [_messages count]; i++) {
        PLChatObject *co = [_messages objectAtIndex:i];
        if(co.isActive){
            if (![messages objectForKey:co.identifier]) {
                [_messages removeObjectAtIndex:i];
            }
        }
    }
    
    // Sort
    [_messages sortUsingDescriptors:
     [NSArray arrayWithObjects:
      [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES], nil]];
    
    // Notify view
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationChatMessagesReceived object:self];
}

- (PLChatObject*)getMessage:(NSString*)key {
    for (PLChatObject *co in _messages) {
        if ([co.identifier isEqualToString: key]) {
            return co;
        }
    }
    return nil;
}

- (NSArray*)getMessagesArray {
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    
    for (PLChatObject *co in _messages) {
        
        if(!co.isActive){
            
            NSDictionary *messageJson = @ {
                @"timestamp": co.timestamp,
                @"identifier": co.identifier,
                @"text": co.text
            };
            [ret addObject:messageJson];
        }
    }
    return ret;
}

@end
