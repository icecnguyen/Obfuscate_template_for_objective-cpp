#import "AntiTamper.h"
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach/mach.h>
#import <CommonCrypto/CommonDigest.h>
#import <pthread.h>
#import <unistd.h>
#import <string.h>
#import <dlfcn.h>

#ifdef __arm64__
#define OBF_JUNK_CODE() \
    __asm__ volatile ( \
        "b 1f\n" \
        ".byte 0xeb\n" \
        "1:\n" \
    )
#else
#define OBF_JUNK_CODE() do {} while(0)
#endif

static unsigned char g_OriginalTextHash[CC_SHA256_DIGEST_LENGTH];
static bool g_HashInitialized = false;

static void CalculateMemoryHash(const void *buffer, size_t size, unsigned char *outHash)
{
    CC_SHA256(buffer, (CC_LONG)size, outHash);
}

static bool GetTextSegment(const void **outAddress, size_t *outSize)
{
#ifdef __arm64__
    OBF_JUNK_CODE();
    Dl_info info;
    if (dladdr((const void*)ObfEnableAntiTamper, &info))
    {
        const struct mach_header_64 *header = (const struct mach_header_64 *)info.dli_fbase;
        unsigned long size = 0;
        uint8_t *text_section = getsectiondata(header, "__TEXT", "__text", &size);
        if (text_section && size > 0)
        {
            *outAddress = text_section;
            *outSize = size;
            return true;
        }
    }
#endif
    return false;
}

bool ObfIsMemoryTampered(void)
{
    OBF_JUNK_CODE();
    if (!g_HashInitialized)
    {
        return false;
    }
    
    const void *textAddr = NULL;
    size_t textSize = 0;
    if (GetTextSegment(&textAddr, &textSize))
    {
        unsigned char currentHash[CC_SHA256_DIGEST_LENGTH];
        CalculateMemoryHash(textAddr, textSize, currentHash);
        
        if (memcmp(currentHash, g_OriginalTextHash, CC_SHA256_DIGEST_LENGTH) != 0)
        {
            return true;
        }
    }
    return false;
}

static void* AntiTamperWatchdog(void* arg)
{
    OBF_JUNK_CODE();
    while (true)
    {
        if (ObfIsMemoryTampered())
        {
#ifdef __arm64__
            asm volatile ("mov x0, #1\n mov x16, #1\n svc #0x80\n");
#else
            _exit(1);
#endif
        }
        sleep(5);
    }
    return NULL;
}

void ObfEnableAntiTamper(void)
{
    const void *textAddr = NULL;
    size_t textSize = 0;
    
    if (GetTextSegment(&textAddr, &textSize))
    {
        CalculateMemoryHash(textAddr, textSize, g_OriginalTextHash);
        g_HashInitialized = true;
        
        typedef int (*pthread_create_t)(pthread_t*, const pthread_attr_t*, void* (*)(void*), void*);
        typedef int (*pthread_detach_t)(pthread_t);
        
        void *libHandle = dlopen(NULL, RTLD_LAZY);
        if (libHandle)
        {
            pthread_create_t p_create = (pthread_create_t)dlsym(libHandle, "pthread_create");
            pthread_detach_t p_detach = (pthread_detach_t)dlsym(libHandle, "pthread_detach");
            
            if (p_create && p_detach) {
                pthread_t thread;
                p_create(&thread, NULL, AntiTamperWatchdog, NULL);
                p_detach(thread);
            }
            dlclose(libHandle);
        }
    }
}