#import "AntiDump.h"
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <string.h>

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

void ObfEnableAntiDump(void)
{
#ifdef __arm64__
    OBF_JUNK_CODE();
    Dl_info info;
    dladdr((const void*)ObfEnableAntiDump, &info);
    if (info.dli_fbase)
    {
        struct mach_header_64 *header = (struct mach_header_64*)info.dli_fbase;
        vm_address_t page = (vm_address_t)header & ~(vm_page_size - 1);
        kern_return_t kr = vm_protect(mach_task_self(), page, vm_page_size, false, VM_PROT_READ | VM_PROT_WRITE);
        
        if (kr == KERN_SUCCESS)
        {
            OBF_JUNK_CODE();
            header->magic = 0;
            header->cputype = 0;
            header->cpusubtype = 0;
            header->filetype = 0;
            uint8_t *cmdPtr = (uint8_t *)header + sizeof(struct mach_header_64);
            for (uint32_t i = 0; i < header->ncmds; i++)
            {
                struct load_command *cmd = (struct load_command *)cmdPtr;
                
                if (cmd->cmd == LC_SYMTAB)
                {
                    memset(cmd, 0, sizeof(struct symtab_command));
                }
                
                if (cmd->cmd == LC_SEGMENT_64)
                {
                    struct segment_command_64 *seg = (struct segment_command_64 *)cmd;
                    if (strncmp(seg->segname, "__TEXT", 16) == 0)
                    {
                        strncpy(seg->segname, "NO_DUMP", 16);
                    }
                }
                
                cmdPtr += cmd->cmdsize;
            }
            
            OBF_JUNK_CODE();
            vm_protect(mach_task_self(), page, vm_page_size, false, VM_PROT_READ | VM_PROT_EXEC);
        }
    }
#endif
}