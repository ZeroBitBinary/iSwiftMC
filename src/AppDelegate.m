#import "AppDelegate.h"
#import "JVMLauncher.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    // Minimal placeholder root VC. The real UI (account picker, version list,
    // settings) replaces this — see docs/ROADMAP.md, phase 4.
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor blackColor];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];

    // Boot the JVM off the main thread so the UI stays responsive while the
    // interpreter spins up. For the scaffold we just verify it loads and prints
    // the Java version; wiring the Minecraft main class comes in phase 3.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *err = nil;
        JVMLauncher *jvm = [[JVMLauncher alloc] init];
        if (![jvm bootInterpreterOnlyWithError:&err]) {
            NSLog(@"[iSwiftMC] JVM boot failed: %@", err);
            return;
        }
        NSLog(@"[iSwiftMC] JVM booted in interpreter-only (-Xint) mode.");
        // TODO(phase 3): [jvm launchMainClass:@"net.minecraft.client.main.Main"
        //                          args:gameArgs];
    });

    return YES;
}

@end
