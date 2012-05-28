//
//  BoincController.mm
//  GGC
//
//  Created by Shawn Goldwasser on 12-05-21.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "BoincController.h"

#import "boinc_api.h"
#import "diagnostics.h"
#import "gui_rpc_client.h"
#import "util.h"

@implementation BoincController

@synthesize rpc;
@synthesize task;
@synthesize projectURLs;
@synthesize selectedProjectIndex;

/* Initialize the BoincController
 * -Defines the list of projects to attach
 * -Launches the Boinc Core Client
 * Returns self
 */
 -(BoincController *)init
{
    self = [super init];
    int err;
    
    // Array of projects
    projectURLs = [[NSArray alloc] initWithObjects:@"boinc.bakerlab.org/rosetta", nil];
    selectedProjectIndex = 0;
    
    // Launch the Boinc Client
    err = [self launchClient];
    if (err) {
        fprintf(stderr, "launchClient failed. err=%d\n", err);
        return self;
    }
    
    // Initialize Boinc
    err = [self initBoinc]; 
    if (err) {
        fprintf(stderr, "initClient failed. err=%d\n", err);
        return self;
    }
    
    // Connect to the Boinc Core Client
    err = [self initRPC]; 
    if (err) {
        fprintf(stderr, "initRPC failed. err=%d\n", err);
        return self;
    }
    
    // Attach to projects (shouldn't be in init)
    err = [self attachProjectsWithEmail:@"shawn@email.com" username:@"name" password:@"pass"];
    if (err) {
        fprintf(stderr, "attachProjectsWithEmail failed. %d\n", err);
        return self;
    }
    
    NSLog(@"boincController Initialized");
    return self;    
}

-(int)launchClient
{    
    NSArray *args;
    NSPipe *pipe;
    NSFileHandle *fileHandle;
    NSData *data;
    NSString *text;
    
    // Arguments to pass to the Boinc Core Client (insecure is needed until security is figured out)
    args = [[NSArray alloc] initWithObjects:@"-insecure", nil];
    
    // A pipe and file handle that the Boinc Core Client will output to
    pipe = [NSPipe pipe];
    fileHandle = [pipe fileHandleForReading];
    
    // Set up a task to launch the Boinc Core Client
    task = [[NSTask alloc] init];
    [task setLaunchPath:@"boinc"];
    [task setArguments:args];
    [task setStandardOutput: pipe];
    [task setStandardError: pipe];
    
    @try {
        // Launch the Boinc Core Client
        [task launch];
    }
    @catch (NSException *e) {
        fprintf(stderr, "clinet failed to launch");
        return 1;
    }
    
    // Check for data through the pipe
    while ((data = [fileHandle availableData]) && [data length]) {
        text = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        // Boinc Core Client finishes intitialization with the string "Initialization complete"
        if ([text rangeOfString:@"Initialization complete"].location != NSNotFound) {
            return 0;
        }
    }
    return 1;
}

/* Initialize Boinc
 */
-(int)initBoinc
{
    int rc;
    boinc_init_diagnostics(BOINC_DIAG_MEMORYLEAKCHECKENABLED|
                           BOINC_DIAG_DUMPCALLSTACKENABLED| 
                           BOINC_DIAG_TRACETOSTDERR);
    rc = boinc_init();
    return rc;
}

/* Connect to the Boinc Core Client
 * Get authorization to control the Boinc Core Client
 */
-(int)initRPC
{
    int rc;
    char rpc_pw[32];
    
    rpc = RPC_CLIENT();
    // Connect to the Boinc Core Client
    rc = rpc.init("127.0.0.1");
    if (rc) {
        return rc;
    }
    
    // Get the Boinc Core Client authorization key
    rc = read_gui_rpc_password(rpc_pw);
    if (rc) {
        return rc;
    }
    
    // Request authorization to control the Boinc Core Client
    rc = rpc.authorize(rpc_pw);
    return rc;
}

/* Attach to the projects using the given credentials
 * Returns 0 on success, Boinc error code on failure
 */
-(int)attachProjectsWithEmail:(NSString *)email username:(NSString *)username password:(NSString *)password
{
    int rc;
    ACCOUNT_IN accti;
    ACCOUNT_OUT accto;
    NSString *project;
    NSString *authenticator;
    NSString *error_msg;
    double maxTime;
    double sleepTime;
    int i;
    
    // Loop through all projects, which should be attached
    for (project in projectURLs)
    {
        // Attach the project if it isn't already attached
        if (![self isProjectAttached:project]) {
            accti = ACCOUNT_IN();
            accto = ACCOUNT_OUT();
            
            // Set up the create_account request
            accti.email_addr = [email cStringUsingEncoding:NSUTF8StringEncoding];
            accti.passwd = [password cStringUsingEncoding:NSUTF8StringEncoding];
            accti.user_name = [username cStringUsingEncoding:NSUTF8StringEncoding];
            accti.url = [project cStringUsingEncoding:NSUTF8StringEncoding];
            
            // Create an account
            rc = rpc.create_account(accti);
            if (rc){
                return rc;
            }
            
            // Wait for the account to be created
            i = 0;
            maxTime = 5.0;
            sleepTime = 0.01;
            while (i < maxTime/sleepTime) {
                // Check if the account info has been returned
                rc = rpc.create_account_poll(accto);
                if (rc){
                    return rc;
                }
                
                // Get the authenticator token
                authenticator = [[NSString alloc] initWithCString:accto.authenticator.c_str() encoding:NSUTF8StringEncoding];
                // Get the error message
                error_msg = [[NSString alloc] initWithCString:accto.error_msg.c_str() encoding:NSUTF8StringEncoding];
                
                // Exit the loop if an authenticator token or error message have been returned
                if ([error_msg length] > 0 || [authenticator length] > 0) {
                    break;
                }
                
                // Pause before next iteration
                boinc_sleep(sleepTime);
                i++;
            }
            
            // Attach to the project (need to change project name)
            rc = rpc.project_attach([project cStringUsingEncoding:NSUTF8StringEncoding], [authenticator cStringUsingEncoding:NSUTF8StringEncoding], "Rosetta@home");
            if (rc){
                return rc;
            }
        }
    }
    
    return 0;
}

/* Check if a project is attached
 * returns true or false
 */
-(bool)isProjectAttached:(NSString *)project
{
    int rc;
    PROJECTS attachedProjects;
    PROJECT attachedProject;
    NSString *attachedProjectString;
    
    // Get the status of all attached projects
    rc = rpc.get_project_status(attachedProjects);
    if (rc){
        fprintf(stderr, "RPC: rpc.get_project_status() failed. rc=%d\n", rc);
    }
    
    // Loop through all attached projects
    for (int i = 0; i < attachedProjects.projects.size(); i++){
        attachedProject = *attachedProjects.projects.at(i);
        
        // Get the URL of the project
        attachedProjectString = [[NSString alloc] initWithCString:attachedProject.master_url encoding:NSUTF8StringEncoding];
        
        // Check if the currect attached project is the project we are looking for
        if ([project compare:attachedProjectString]){
            return true;
        }
    }
    
    // Return false if we've looked through the entire list
    return false;
}

-(void)getStatus
{
    int rc;
    RESULTS results;
    RESULT result;
    PROJECTS attachedProjects;
    
    rc = rpc.get_results(results);
    rc = rpc.get_project_status(attachedProjects);
    
    fprintf(stderr, "results length %lu\n", results.results.size());
    fprintf(stderr, "project length %lu\n", attachedProjects.projects.size());
    if (results.results.size()) {
        result = *results.results.at(0);
        fprintf(stderr, "%f\n", result.fraction_done);
    }
}

-(void)startTask
{
    int rc;
    PROJECTS projects;
    PROJECT project;
    
    rc = rpc.get_project_status(projects);
    if (rc) {
        fprintf(stderr, "%d\n", rc);
    }
    
    project = *projects.projects.at(selectedProjectIndex);
    rc = rpc.project_op(project, "resume");
}
-(void)stopTask
{
    int rc;
    PROJECTS projects;
    PROJECT project;
    
    rc = rpc.get_project_status(projects);
    if (rc) {
        fprintf(stderr, "%d\n", rc);
    }
    
    project = *projects.projects.at(selectedProjectIndex);
    rc = rpc.project_op(project, "suspend");
}

/* Close all connections
 * Exit the Boinc Core Client
 * Clean up Boinc
 */
-(void)terminate
{
    int rc;
    
    // Exit the Boinc Core Client
    rc = rpc.quit();
    if (rc) {
        fprintf(stderr, "rc=%d\n", rc);
        // Interrupt the Boinc Core Client if it couldn't be exited gracefully
        [task interrupt];
    }
    
    // Clean up Boinc
    boinc_finish(nil);
}

extern int read_gui_rpc_password2(char* buf) {
    FILE* f = fopen(GUI_RPC_PASSWD_FILE, "r");
    if (!f) return ERR_FOPEN;
    char* p = fgets(buf, 256, f);
    if (p) {
        // trim CR
        //
        int n = (int)strlen(buf);
        if (n && buf[n-1]=='\n') {
            buf[n-1] = 0;
        }
    }
    fclose(f);
    return 0;
}

@end
