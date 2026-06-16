#import "JVMLauncher.h"
#import <dlfcn.h>
#import <jni.h>

// JNI_CreateJavaVM signature, resolved from the bundled libjvm at runtime.
typedef jint (*CreateJavaVM_t)(JavaVM **pvm, void **penv, void *args);

@implementation JVMLauncher {
    JavaVM *_vm;
    JNIEnv *_env;
}

/// Path to the bundled JRE root, e.g. .../iSwiftMC.app/runtimes/jre
- (NSString *)bundledJREPath {
    NSString *res = [[NSBundle mainBundle] resourcePath];
    return [res stringByAppendingPathComponent:@"runtimes/jre"];
}

/// Writable app sandbox dir we point user.home/tmp/log at.
+ (NSString *)docsDir {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                NSUserDomainMask, YES) firstObject];
}

/// Where the JVM's stdout/stderr from the *previous* run is captured.
+ (NSString *)jvmLogPath {
    return [[self docsDir] stringByAppendingPathComponent:@"jvm-output.txt"];
}

- (BOOL)bootInterpreterOnlyWithError:(NSError **)error {
    NSString *jre  = [self bundledJREPath];
    NSString *docs = [JVMLauncher docsDir];
    NSString *libjvm = [jre stringByAppendingPathComponent:@"lib/server/libjvm.dylib"];

    // Capture everything the JVM prints (incl. fatal errors) so we can show it
    // on next launch even if the VM aborts the whole process.
    freopen([JVMLauncher jvmLogPath].fileSystemRepresentation, "w", stdout);
    freopen([JVMLauncher jvmLogPath].fileSystemRepresentation, "a", stderr);
    // Unbuffered: a hard crash mid-init still leaves every line on disk.
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
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

    // --- Interpreter-only (no JIT) + the iOS-survival flags PojavLauncher needs ---
    //  -Xint         : pure interpreter (no writable-executable memory needed)
    //  -Xrs          : don't install signal handlers (they conflict on iOS -> crash)
    //  ErrorFile     : write fatal-error log somewhere we can read it
    //  user.home/tmp : iOS sandbox is read-only except Documents/tmp
    NSMutableArray<NSString *> *opts = [@[
        @"-Xint",
        @"-Xrs",
        [NSString stringWithFormat:@"-Djava.home=%@", jre],
        [NSString stringWithFormat:@"-Djava.library.path=%@", libDir],
        [NSString stringWithFormat:@"-Duser.home=%@", docs],
        [NSString stringWithFormat:@"-Duser.dir=%@", docs],
        [NSString stringWithFormat:@"-Djava.io.tmpdir=%@", NSTemporaryDirectory()],
        @"-XX:+UnlockExperimentalVMOptions",
        @"-XX:-UsePerfData",
        [NSString stringWithFormat:@"-XX:ErrorFile=%@", hsErr],
        @"-Xmx512M",
    ] mutableCopy];

    JavaVMOption *cOpts = calloc(opts.count, sizeof(JavaVMOption));
    for (NSUInteger i = 0; i < opts.count; i++) {
        cOpts[i].optionString = strdup(opts[i].UTF8String);
        fprintf(stderr, "[iSwiftMC] opt: %s\n", cOpts[i].optionString);
    }
    fflush(stderr);

    JavaVMInitArgs vmArgs = {0};
    vmArgs.version = JNI_VERSION_1_8;
    vmArgs.nOptions = (jint)opts.count;
    vmArgs.options = cOpts;
    vmArgs.ignoreUnrecognized = JNI_TRUE;  // tolerate unknown flags rather than abort

    jint rc = createVM(&_vm, (void **)&_env, &vmArgs);

    for (NSUInteger i = 0; i < opts.count; i++) free(cOpts[i].optionString);
    free(cOpts);

    fprintf(stderr, "[iSwiftMC] JNI_CreateJavaVM rc=%d\n", rc);
    fflush(stderr);

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
