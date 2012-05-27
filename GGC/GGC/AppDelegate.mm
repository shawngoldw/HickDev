//
//  AppDelegate.m
//  GGC
//
//  Created by Shawn Goldwasser on 12-05-11.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "BoincController.h"

#import "util.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize boincController;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    boincController = [[BoincController alloc] init];
}

-(void)applicationWillTerminate:(NSNotification *)notification; 
{
    [boincController terminate];
}

- (IBAction)pressButton:(NSButton *)sender {
    NSString *val;
    
    val = [sender title];
    if ([val isEqualToString:@"Stop"]) {
        [boincController stopTask];
        [sender setTitle:@"Start"];
    } else {
        [boincController startTask];
        [sender setTitle:@"Stop"];
    }
}
@end
