//
//  BoincController.h
//  GGC
//
//  Created by Shawn Goldwasser on 12-05-21.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "gui_rpc_client.h"

@interface BoincController : NSObject

@property(assign) RPC_CLIENT rpc;

@property(retain) NSTask *task;

@property(retain) NSArray *projectURLs;
@property(assign) int selectedProjectIndex;

-(BoincController *)init;

-(int)launchClient;
-(int)initBoinc;
-(int)initRPC;

-(int)attachProjectsWithEmail:(NSString *)email username:(NSString *)username password:(NSString *)password;
-(bool)isProjectAttached:(NSString *)project;

-(void)getStatus;
-(void)startTask;
-(void)stopTask;

-(void)terminate;

@end
