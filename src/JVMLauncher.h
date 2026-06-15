#import <Foundation/Foundation.h>

/// Loads the bundled OpenJDK and starts a JVM in interpreter-only (-Xint) mode,
/// i.e. no JIT. This is the only mode usable on a normally-sideloaded iOS app.
@interface JVMLauncher : NSObject

/// Locates the bundled runtime in the app's resources, dlopen's libjvm, and
/// calls JNI_CreateJavaVM with -Xint plus the standard module/classpath args.
/// Returns NO and populates *error on failure.
- (BOOL)bootInterpreterOnlyWithError:(NSError **)error;

/// Invokes a Java main class (e.g. Minecraft) on the current JVM. Requires a
/// prior successful boot. (Implemented in phase 3.)
- (BOOL)launchMainClass:(NSString *)mainClass args:(NSArray<NSString *> *)args;

@end
