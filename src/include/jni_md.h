/*
 * Machine-dependent JNI typedefs for Darwin/Apple (arm64, iOS).
 * jni.h does `#include "jni_md.h"`, so this lives next to our vendored jni.h.
 * Matches the OpenJDK macOS/bsd definitions. We only build for arm64 (LP64).
 */

#ifndef _JAVASOFT_JNI_MD_H_
#define _JAVASOFT_JNI_MD_H_

#define JNIEXPORT __attribute__((visibility("default")))
#define JNIIMPORT
#define JNICALL

typedef int jint;
#ifdef _LP64 /* 64-bit (arm64/x86_64) */
typedef long jlong;
#else
typedef long long jlong;
#endif

typedef signed char jbyte;

#endif /* !_JAVASOFT_JNI_MD_H_ */
