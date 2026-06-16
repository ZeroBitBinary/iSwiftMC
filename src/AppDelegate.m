#import "AppDelegate.h"
#import "JVMLauncher.h"

@implementation AppDelegate {
    UITextView *_console;
    UIButton *_bootBtn;
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

    CGRect b = root.view.bounds;
    CGFloat btnH = 90;
    _console = [[UITextView alloc] initWithFrame:
        CGRectMake(0, 0, b.size.width, b.size.height - btnH)];
    _console.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _console.backgroundColor = [UIColor blackColor];
    _console.textColor = [UIColor greenColor];
    _console.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    _console.editable = NO;
    _console.text = [NSString stringWithFormat:@"iSwiftMC diagnostic build (v3 — JIT)\nJIT enabled right now: %@\n",
                     [JVMLauncher isJITEnabled] ? @"YES ✅" : @"NO ❌ (enable in StikDebug first)"];
    [root.view addSubview:_console];

    // Boot is MANUAL now, so a crash trail stays readable on the next launch.
    _bootBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _bootBtn.frame = CGRectMake(0, b.size.height - btnH, b.size.width, btnH);
    _bootBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _bootBtn.backgroundColor = [UIColor colorWithRed:0 green:0.4 blue:0 alpha:1];
    [_bootBtn setTitle:@"▶ TAP TO BOOT JVM" forState:UIControlStateNormal];
    [_bootBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _bootBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [_bootBtn addTarget:self action:@selector(bootTapped) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:_bootBtn];

    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];

    // Show the JVM output captured during the PREVIOUS launch. Because we no
    // longer auto-boot, this stays on screen for you to read/screenshot.
    NSString *prev = [NSString stringWithContentsOfFile:[JVMLauncher jvmLogPath]
                                               encoding:NSUTF8StringEncoding error:nil];
    NSString *hsErr = [NSString stringWithContentsOfFile:
        [[JVMLauncher docsDir] stringByAppendingPathComponent:@"hs_err.log"]
                                               encoding:NSUTF8StringEncoding error:nil];
    if (prev.length) {
        [self log:@"=========== PREVIOUS RUN OUTPUT ==========="];
        [self log:prev];
        [self log:@"=========== END PREVIOUS OUTPUT ==========="];
    } else {
        [self log:@"(no previous JVM output yet — tap the button to boot)"];
    }
    if (hsErr.length) {
        [self log:@"--- previous fatal error (hs_err) ---"];
        [self log:[hsErr substringToIndex:MIN(hsErr.length, 3000u)]];
    }
    return YES;
}

- (void)bootTapped {
    // Check JIT up front so we give guidance instead of a silent SIGKILL.
    if (![JVMLauncher isJITEnabled]) {
        [self log:@"⚠️ JIT is NOT enabled for this app."];
        [self log:@"   1) Open StikDebug  2) Enable JIT for iSwiftMC  3) return here, tap Boot."];
        [self log:@"   (A JVM cannot run on iOS without JIT — this is expected.)"];
        return;
    }
    _bootBtn.enabled = NO;
    [_bootBtn setTitle:@"booting…" forState:UIControlStateNormal];
    [self log:@"✅ JIT detected. Booting JVM (with JIT)…"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *err = nil;
        JVMLauncher *jvm = [[JVMLauncher alloc] init];
        BOOL ok = [jvm bootJVMWithError:&err];
        if (ok) {
            [self log:@"✅ JVM booted with JIT. (no crash!)"];
        } else {
            [self log:[NSString stringWithFormat:@"❌ boot returned failure: %@",
                       err.localizedDescription]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_bootBtn.enabled = YES;
            [self->_bootBtn setTitle:@"▶ BOOT AGAIN" forState:UIControlStateNormal];
        });
    });
}

@end
