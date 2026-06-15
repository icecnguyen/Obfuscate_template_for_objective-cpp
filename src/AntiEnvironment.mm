#import "AntiEnvironment.h"
#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <stdlib.h>
#import <string.h>

#ifdef __arm64__
#define OBF_JUNK_CODE() \
    __asm__ volatile ( \
        "b 1f\n" \
        ".byte 0xeb\n" \
        "1:\n" \
    )

static inline int obf_syscall_stat(const char *path, struct stat *buf) {
    long ret;
    __asm__ volatile (
        "mov x0, %1\n"
        "mov x1, %2\n"
        "mov x16, #338\n"
        "svc #0x80\n"
        "mov %0, x0\n"
        : "=r" (ret) : "r" (path), "r" (buf) : "x0", "x1", "x16", "memory"
    );
    return (int)ret;
}

static inline int obf_syscall_lstat(const char *path, struct stat *buf) {
    long ret;
    __asm__ volatile (
        "mov x0, %1\n"
        "mov x1, %2\n"
        "mov x16, #340\n"
        "svc #0x80\n"
        "mov %0, x0\n"
        : "=r" (ret) : "r" (path), "r" (buf) : "x0", "x1", "x16", "memory"
    );
    return (int)ret;
}
#else
#define OBF_JUNK_CODE() do {} while(0)
static inline int obf_syscall_stat(const char *path, struct stat *buf) { return stat(path, buf); }
static inline int obf_syscall_lstat(const char *path, struct stat *buf) { return lstat(path, buf); }
#endif

bool ObfIsJailbrokenOrTampered(void)
{
    OBF_JUNK_CODE();
    
    const char *jailbreak_paths[] = {
        "/Applications/Cydia.app",
        "/Applications/Sileo.app",
        "/Applications/Zebra.app",
        "/Applications/TrollStore.app",
        "/Applications/TrollInstallerX.app",
        "/Applications/Dopamine.app",
        "/Applications/Palera1n.app",
        "/Applications/unc0ver.app",
        "/Applications/Taurine.app",
        "/usr/sbin/sshd",
        "/bin/bash",
        "/etc/apt",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/Library/MobileSubstrate/DynamicLibraries",
        "/var/jb",
        "/var/jb/Applications/Sileo.app",
        "/var/jb/usr/bin/bash",
        "/var/jb/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/var/jb/usr/bin/cycript",
        "/var/jb/usr/bin/ssh",
        "/var/jb/usr/bin/scp",
        "/var/jb/etc/apt",
        "/var/lib/apt",
        "/var/lib/cydia",
        "/var/log/syslog",
        "/var/tmp/cydia.log",
        "/private/var/lib/apt",
        "/private/var/Users/",
        "/private/var/mobile/Library/SBSettings/Themes",
        "/.bootstrapped_electra",
        "/.cydia_no_stash",
        "/.installed_unc0ver",
        NULL
    };
    
    for (int i = 0; jailbreak_paths[i] != NULL; i++)
    {
        struct stat stat_info;
        if (obf_syscall_stat(jailbreak_paths[i], &stat_info) == 0)
        {
            return true;
        }
    }
    
    OBF_JUNK_CODE();
    
    struct stat lstat_info;
    if (obf_syscall_lstat("/var/jb", &lstat_info) == 0)
    {
        if (S_ISLNK(lstat_info.st_mode))
        {
            return true;
        }
    }
    
    char *env = getenv("DYLD_INSERT_LIBRARIES");
    if (env != NULL)
    {
        return true;
    }
    
    OBF_JUNK_CODE();
    
    NSError *error;
    NSString *testPath = @"/private/test_sandbox.txt";
    [@"test" writeToFile:testPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!error)
    {
        [[NSFileManager defaultManager] removeItemAtPath:testPath error:nil];
        return true;
    }

    return false;
}