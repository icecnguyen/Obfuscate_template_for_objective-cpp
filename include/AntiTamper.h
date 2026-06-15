#ifndef AntiTamper_h
#define AntiTamper_h

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdbool.h>

void ObfEnableAntiTamper(void);

bool ObfIsMemoryTampered(void);

#ifdef __cplusplus
}
#endif

#endif