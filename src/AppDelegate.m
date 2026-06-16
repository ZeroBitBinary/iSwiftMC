#import "AppDelegate.h"
#import "JVMLauncher.h"

@implementation AppDelegate {
    UITextView *_console;
}

- (void)log:(NSString *)line {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_console.text = [self->_console.text stringByAppendingFormat:@"%@\n", line];
    });
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor blackColor];

    // On-screen console so we can see what happens without a Mac/Xcode attached.
    _console = [[UITextView alloc] initWithFrame:root.view.bounds];
    _console.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _console.backgroundColor = [UIColor blackColor];
    _console.textColor = [UIColor greenColor];
    _console.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    _console.editable = NO;
    _console.text = @"iSwiftMC diagnostic build\n";
    [root.view addSubview:_console];

    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];

    // Show the JVM output captured during the PREVIOUS launch (it's written to a
    // file before the VM can abort the process, so a crash still leaves a trail).
    NSString *prev = [NSString stringWithContentsOfFile:[JVMLauncher jvmLogPath]
                                               encoding:NSUTF8StringEncoding error:nil];
    NSString *hsErr = [NSString stringWithContentsOfFile:
        [[JVMLauncher docsDir] stringByAppendingPathComponent:@"hs_err.log"]
                                               encoding:NSUTF8StringEncoding error:nil];
    if (prev.length)  [self log:[@"--- previous JVM output ---\n" stringByAppendingString:prev]];
    if (hsErr.length) [self log:[@"--- previous fatal error ---\n" stringByAppendingString:
                                 [hsErr substringToIndex:MIN(hsErr.length, 2000u)]]];

    [self log:@"--- this launch: booting JVM (-Xint, no JIT) ---"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *err = nil;
        JVMLauncher *jvm = [[JVMLauncher alloc] init];
        BOOL ok = [jvm bootInterpreterOnlyWithError:&err];
        if (ok) {
            [self log:@"✅ JVM booted in interpreter-only mode."];
        } else {
            [self log:[NSString stringWithFormat:@"❌ JVM boot failed: %@",
                       err.localizedDescription]];
            [self log:@"(if the app vanished instead of showing this, the VM "
                       @"aborted — reopen to see the captured output above.)"];
        }
    });

    return YES;
}

@end
