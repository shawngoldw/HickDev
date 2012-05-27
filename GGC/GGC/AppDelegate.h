//
//  AppDelegate.h
//  GGC
//
//  Created by Shawn Goldwasser on 12-05-11.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BoincController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (retain) BoincController *boincController;
- (IBAction)pressButton:(NSButton *)sender;

@end
