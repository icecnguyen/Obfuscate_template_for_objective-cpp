#import "AntiHook.h"
#import <stdint.h>
#import <stddef.h>
#import <dlfcn.h>
#import <string.h>

bool ObfIsHooked(void *targetFunction)
{
#ifdef __arm64__
    if (!targetFunction)
    {
        return false;
    }
    
    uint32_t *instructions = (uint32_t*)targetFunction;
    for (int i = 0; i < 16; ++i)
    {
        uint32_t instruction = instructions[i];

        if ((instruction & 0xFC000000) == 0x14000000)
        {
            return true;
        }

        if ((instruction & 0xFFFFFC1F) == 0xD61F0000)
        {
            return true;
        }

        if ((instruction & 0xFF000000) == 0x58000000)
        {
            uint32_t rt = instruction & 0x1F;
            if (rt == 16 || rt == 17)
            {
                return true;
            }
        }

        if ((instruction & 0x9F000000) == 0x90000000)
        {
            uint32_t rd = instruction & 0x1F;
            if (rd == 16 || rd == 17)
            {
                return true;
            }
        }
    }
#endif
    return false;
}

bool ObfIsFunctionOutsourced(void *targetFunction)
{
    if (!targetFunction)
    {
        return false;
    }
    
    Dl_info info;
    if (dladdr(targetFunction, &info))
    {
        if (info.dli_fname)
        {
            const char *fname = info.dli_fname;
            if (strstr(fname, "Substrate") || 
                strstr(fname, "Substitute") || 
                strstr(fname, "Frida") || 
                strstr(fname, "dobby") || 
                strstr(fname, "ElleKit") ||
                strstr(fname, "fishhook") ||
                strstr(fname, "CydiaSubstrate") ||
                strstr(fname, "libhooker"))
            {
                return true;
            }
        }
    }
    return false;
}