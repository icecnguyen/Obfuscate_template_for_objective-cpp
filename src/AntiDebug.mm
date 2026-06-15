#import "AntiDebug.h"
#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <pthread.h>

#ifdef __arm64__
#define OBF_JUNK_CODE() \
    __asm__ volatile ( \
        "b 1f\n" \
        ".byte 0xeb\n" \
        "1:\n" \
    )

static inline int obf_syscall_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    long ret;
    __asm__ volatile (
        "mov x0, %1\n"
        "mov x1, %2\n"
        "mov x2, %3\n"
        "mov x3, %4\n"
        "mov x4, %5\n"
        "mov x5, %6\n"
        "mov x16, #202\n"
        "svc #0x80\n"
        "mov %0, x0\n"
        : "=r" (ret)
        : "r" (name), "r" ((long)namelen), "r" (oldp), "r" (oldlenp), "r" (newp), "r" (newlen)
        : "x0", "x1", "x2", "x3", "x4", "x5", "x16", "memory"
    );
    return (int)ret;
}
#else
#define OBF_JUNK_CODE() do {} while(0)
static inline int obf_syscall_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) { return sysctl(name, namelen, oldp, oldlenp, newp, newlen); }
#endif

void ObfPtraceDenyAttach(void)
{
    OBF_JUNK_CODE();
#ifdef __arm64__
    asm volatile ("mov x0, #31\n" "mov x1, #0\n" "mov x2, #0\n" "mov x3, #0\n" "mov x16, #26\n" "svc #0x80\n");
#else
    void* handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    if (handle)
    {
        typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);
        ptrace_ptr_t ptrace_ptr = (ptrace_ptr_t)dlsym(handle, "ptrace");
        if (ptrace_ptr) ptrace_ptr(31, 0, 0, 0);
        dlclose(handle);
    }
#endif
}

int ObfCheckSysctl(void)
{
    OBF_JUNK_CODE();
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    size_t size = sizeof(info);
    info.kp_proc.p_flag = 0;
    
    if (obf_syscall_sysctl(mib, 4, &info, &size, NULL, 0) == -1)
    {
        return 1;
    }
    if (info.kp_proc.p_flag & P_TRACED)
    {
        return 1;
    }
    return 0;
}

int ObfCheckHardwareBreakpoints(void)
{
#ifdef __arm64__
    OBF_JUNK_CODE();
    arm_debug_state64_t dbg_state;
    mach_msg_type_number_t count = ARM_DEBUG_STATE64_COUNT;
    kern_return_t kr = thread_get_state(mach_thread_self(), ARM_DEBUG_STATE64, (thread_state_t)&dbg_state, &count);
    if (kr == KERN_SUCCESS)
    {
        for (int i = 0; i < 16; i++)
        {
            if (dbg_state.__bcr[i] != 0 || dbg_state.__bvr[i] != 0)
            {
                return 1;
            }
            if (dbg_state.__wcr[i] != 0 || dbg_state.__wvr[i] != 0)
            {
                return 1;
            }
        }
    }
#endif
    return 0;
}

void ObfDenyExceptionPort(void)
{
    OBF_JUNK_CODE();
    task_set_exception_ports(mach_task_self(), EXC_MASK_ALL, MACH_PORT_NULL, EXCEPTION_DEFAULT, THREAD_STATE_NONE);
}

bool ObfCheckIsatty(void)
{
    if (isatty(STDOUT_FILENO))
    {
        return true;
    }
    return false;
}

static void* WatchdogThread(void* arg)
{
    OBF_JUNK_CODE();
    while (true)
    {
        if (ObfCheckSysctl() || ObfCheckHardwareBreakpoints() || ObfCheckIsatty())
        {
#ifdef __arm64__
            asm volatile ("mov x0, #1\n" "mov x16, #1\n" "svc #0x80\n");
#else
            _exit(1);
#endif
        }
        sleep(3);
    }
    return NULL;
}

void ObfEnableAntiDebug(void)
{
    ObfPtraceDenyAttach();
    ObfDenyExceptionPort();
    
    if (ObfCheckSysctl() || ObfCheckHardwareBreakpoints() || ObfCheckIsatty())
    {
#ifdef __arm64__
        asm volatile ("mov x0, #1\n" "mov x16, #1\n" "svc #0x80\n");
#else
        _exit(1);
#endif
    }
    
    typedef int (*pthread_create_t)(pthread_t*, const pthread_attr_t*, void* (*)(void*), void*);
    typedef int (*pthread_detach_t)(pthread_t);
    
    void *libHandle = dlopen(NULL, RTLD_LAZY);
    if (libHandle)
    {
        pthread_create_t p_create = (pthread_create_t)dlsym(libHandle, "pthread_create");
        pthread_detach_t p_detach = (pthread_detach_t)dlsym(libHandle, "pthread_detach");
        
        if (p_create && p_detach)
        {
            pthread_t thread;
            p_create(&thread, NULL, WatchdogThread, NULL);
            p_detach(thread);
        }
        dlclose(libHandle);
    }
}