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

- (BOOL)bootInterpreterOnlyWithError:(NSError **)error {
    NSString *jre = [self bundledJREPath];
    NSString *libjvm = [jre stringByAppendingPathComponent:@"lib/server/libjvm.dylib"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:libjvm]) {
        if (error) *error = [NSError errorWithDomain:@"iSwiftMC" code:1 userInfo:@{
            NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"libjvm not found at %@. Did "
                 @"scripts/fetch-deps.sh run before the build?", libjvm]}];
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

    // --- The crux: force interpreter-only execution. No JIT. ---
    // -Xint disables C1/C2, so the JVM never needs writable-executable memory.
    NSMutableArray<NSString *> *opts = [@[
        @"-Xint",
        [NSString stringWithFormat:@"-Djava.home=%@", jre],
        // Conservative heap; iOS is memory-constrained and the OS will jetsam us.
        @"-Xmx1024M",
        @"-XX:+UnlockExperimentalVMOptions",
        @"-Djava.library.path=" // filled in phase 3 (gl4es/ANGLE/LWJGL natives)
    ] mutableCopy];

    JavaVMOption *cOpts = calloc(opts.count, sizeof(JavaVMOption));
    for (NSUInteger i = 0; i < opts.count; i++) {
        cOpts[i].optionString = strdup(opts[i].UTF8String);
    }

    JavaVMInitArgs vmArgs = {0};
    vmArgs.version = JNI_VERSION_1_8;
    vmArgs.nOptions = (jint)opts.count;
    vmArgs.options = cOpts;
    vmArgs.ignoreUnrecognized = JNI_FALSE;

    jint rc = createVM(&_vm, (void **)&_env, &vmArgs);

    for (NSUInteger i = 0; i < opts.count; i++) free(cOpts[i].optionString);
    free(cOpts);

    if (rc != JNI_OK) {
        if (error) *error = [NSError errorWithDomain:@"iSwiftMC" code:4 userInfo:@{
            NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"JNI_CreateJavaVM returned %d", rc]}];
        return NO;
    }
    return YES;
}

- (BOOL)launchMainClass:(NSString *)mainClass args:(NSArray<NSString *> *)args {
    // TODO(phase 3): FindClass(mainClass) → GetStaticMethodID "main"
    // ([Ljava/lang/String;)V → build a String[] from args → CallStaticVoidMethod.
    // Must run on a thread attached via AttachCurrentThread.
    NSLog(@"[iSwiftMC] launchMainClass not yet implemented: %@", mainClass);
    return NO;
}

@end
