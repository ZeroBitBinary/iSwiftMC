#import "JVMLauncher.h"
#import <dlfcn.h>
#import <jni.h>
#import <unistd.h>
#import <sys/sysctl.h>

// JNI_CreateJavaVM signature, resolved from the bundled libjvm at runtime.
typedef jint (*CreateJavaVM_t)(JavaVM **pvm, void **penv, void *args);

// csops() is a libsystem syscall wrapper used to read this process's code-signing
// status. CS_DEBUGGED is set once a debugger has attached, which on iOS is exactly
// the condition under which the kernel permits writable-executable (JIT) memory.
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define CS_OPS_STATUS 0
#define CS_DEBUGGED   0x10000000
#ifndef P_TRACED
#define P_TRACED      0x00000800
#endif

@implementation JVMLauncher {
    JavaVM *_vm;
    JNIEnv *_env;
}

/// Path to the bundled JRE root, e.g. .../iSwiftMC.app/runtimes/jre
- (NSString *)bundledJREPath {
    NSString *res = [[NSBundle mainBundle] resourcePath];
    return [res stringByAppendingPathComponent:@"runtimes/jre"];
}

+ (NSString *)docsDir {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                NSUserDomainMask, YES) firstObject];
}

+ (NSString *)jvmLogPath {
    return [[self docsDir] stringByAppendingPathComponent:@"jvm-output.txt"];
}

/// YES when JIT (writable-executable memory) is available for this process.
/// A JVM cannot run on iOS without this — even -Xint generates native stubs that
/// need an executable code cache. Enabled per-launch by StikDebug/SideStore.
+ (BOOL)isJITEnabled {
    int flags = 0;
    if (csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags)) == 0) {
        if (flags & CS_DEBUGGED) return YES;
    }
    // Fallback: a traced process (debugger attached) likewise has JIT permission.
    struct kinfo_proc info; size_t size = sizeof(info);
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    if (sysctl(mib, 4, &info, &size, NULL, 0) == 0)
        return (info.kp_proc.p_flag & P_TRACED) != 0;
    return NO;
}

- (BOOL)bootJVMWithError:(NSError **)error {
    NSString *jre  = [self bundledJREPath];
    NSString *docs = [JVMLauncher docsDir];
    NSString *libjvm = [jre stringByAppendingPathComponent:@"lib/server/libjvm.dylib"];

    freopen([JVMLauncher jvmLogPath].fileSystemRepresentation, "w", stdout);
    freopen([JVMLauncher jvmLogPath].fileSystemRepresentation, "a", stderr);
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    // CRUCIAL: bail BEFORE touching the VM if JIT isn't on. Otherwise the kernel
    // SIGKILLs us (CODESIGNING/Invalid Page) the instant the VM runs generated
    // code, with no chance to report anything.
    BOOL jit = [JVMLauncher isJITEnabled];
    fprintf(stderr, "[iSwiftMC] JIT enabled: %s\n", jit ? "YES" : "NO");
    if (!jit) {
        if (error) *error = [NSError errorWithDomain:@"iSwiftMC" code:10 userInfo:@{
            NSLocalizedDescriptionKey:
                @"JIT is NOT enabled. Open StikDebug, enable JIT for iSwiftMC, "
                @"then come back and tap Boot. (A JVM cannot run on iOS without JIT.)"}];
        return NO;
    }

    fprintf(stderr, "[iSwiftMC] boot: jre=%s\n", jre.fileSystemRepresentation);
    if (![[NSFileManager defaultManager] fileExistsAtPath:libjvm]) {
        if (error) *error = [NSError errorWithDomain:@"iSwiftMC" code:1 userInfo:@{
            NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"libjvm not found at %@", libjvm]}];
        return NO;
    }

    void *h = dlopen(libjvm.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
    if (!h) {
        if (error) *error = [NSError errorWithDomain:@"iSwiftMC" code:2 userInfo:@{
            NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"dlopen(libjvm) failed: %s", dlerror()]}];
        return NO;
    }

    CreateJavaVM_t createVM = (CreateJavaVM_t)dlsym(h, "JNI_CreateJavaVM");
    if (!createVM) {
        if (error) *error = [NSError errorWithDomain:@"iSwiftMC" code:3 userInfo:@{
            NSLocalizedDescriptionKey: @"JNI_CreateJavaVM symbol missing"}];
        return NO;
    }

    NSString *libDir = [jre stringByAppendingPathComponent:@"lib"];
    NSString *hsErr  = [docs stringByAppendingPathComponent:@"hs_err.log"];

    // JIT mode: let HotSpot use its compilers + native code cache (JIT is on).
    // We do NOT pass -Xint or -Xrs: the VM needs its real signal handlers for
    // null-checks/safepoints once compiled code runs.
    NSMutableArray<NSString *> *opts = [@[
        [NSString stringWithFormat:@"-Djava.home=%@", jre],
        [NSString stringWithFormat:@"-Djava.library.path=%@", libDir],
        [NSString stringWithFormat:@"-Duser.home=%@", docs],
        [NSString stringWithFormat:@"-Duser.dir=%@", docs],
        [NSString stringWithFormat:@"-Djava.io.tmpdir=%@", NSTemporaryDirectory()],
        @"-XX:+UnlockExperimentalVMOptions",
        @"-XX:-UsePerfData",
        [NSString stringWithFormat:@"-XX:ErrorFile=%@", hsErr],
        @"-Xmx1024M",
    ] mutableCopy];

    JavaVMOption *cOpts = calloc(opts.count, sizeof(JavaVMOption));
    for (NSUInteger i = 0; i < opts.count; i++) {
        cOpts[i].optionString = strdup(opts[i].UTF8String);
        fprintf(stderr, "[iSwiftMC] opt: %s\n", cOpts[i].optionString);
    }

    JavaVMInitArgs vmArgs = {0};
    vmArgs.version = JNI_VERSION_1_8;
    vmArgs.nOptions = (jint)opts.count;
    vmArgs.options = cOpts;
    vmArgs.ignoreUnrecognized = JNI_TRUE;

    jint rc = createVM(&_vm, (void **)&_env, &vmArgs);

    for (NSUInteger i = 0; i < opts.count; i++) free(cOpts[i].optionString);
    free(cOpts);

    fprintf(stderr, "[iSwiftMC] JNI_CreateJavaVM rc=%d\n", rc);

    if (rc != JNI_OK) {
        if (error) *error = [NSError errorWithDomain:@"iSwiftMC" code:4 userInfo:@{
            NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"JNI_CreateJavaVM returned %d", rc]}];
        return NO;
    }
    return YES;
}

- (BOOL)launchMainClass:(NSString *)mainClass args:(NSArray<NSString *> *)args {
    NSLog(@"[iSwiftMC] launchMainClass not yet implemented: %@", mainClass);
    return NO;
}

@end
