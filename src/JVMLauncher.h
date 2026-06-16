#import <Foundation/Foundation.h>

/// Loads the bundled OpenJDK and starts a JVM. Requires JIT to be enabled for the
/// process (see +isJITEnabled) — a JVM needs an executable code cache even in
/// interpreter mode, which iOS only permits once a debugger has attached.
@interface JVMLauncher : NSObject

/// Writable Documents dir (user.home/working dir for the JVM).
+ (NSString *)docsDir;
/// File the JVM's stdout/stderr is redirected to (survives a VM abort).
+ (NSString *)jvmLogPath;
/// YES when JIT (writable-executable memory) is available for this process.
+ (BOOL)isJITEnabled;

/// Locates the bundled runtime, dlopen's libjvm, and calls JNI_CreateJavaVM.
/// Returns NO (without crashing) if JIT is off or boot fails, populating *error.
- (BOOL)bootJVMWithError:(NSError **)error;

/// Invokes a Java main class (e.g. Minecraft) on the current JVM. Requires a
/// prior successful boot. (Implemented in phase 3.)
- (BOOL)launchMainClass:(NSString *)mainClass args:(NSArray<NSString *> *)args;

@end
