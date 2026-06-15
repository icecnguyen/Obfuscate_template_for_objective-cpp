# Obfuscate template for objective c++

Một framework nhỏ gọn, dễ dàng tích hợp dành riêng cho các dự án Theos / Tweak iOS. Cung cấp các biện pháp phòng thủ cơ bản đến nâng cao (Extreme Security) để chống lại dịch ngược (Reverse Engineering), Gỡ lỗi (Debugging), và can thiệp bộ nhớ (Hooking/Dumping). Đặc biệt, hệ thống được thiết kế dạng **Tự trị (Modular)**, người dùng có thể kích hoạt từng chức năng tùy theo nhu cầu và không hề phụ thuộc lẫn nhau.

## Tính năng (Features)

1. **String Encryption (`StringObfuscation.hpp`)**: Mã hoá chuỗi văn bản tại thời gian biên dịch (Compile-time) bằng thuật toán XOR sinh random theo thời gian, giúp ẩn các chuỗi nhạy cảm khỏi `strings`, IDA Pro, Hopper.
2. **Objective-C Obfuscation (`ObjCObfuscation.h/.mm`)**: Ẩn các class và selector bằng cách kết nối với hệ thống String Encryption, tránh lưu lại cấu trúc trong Header Dump.
3. **Anti-Debugging (`AntiDebug.h/.mm`)** (Extreme Security):
   - Check cờ `sysctl` (`P_TRACED`) qua Direct Syscall.
   - Tịch thu các tín hiệu bẫy lỗi bằng `task_set_exception_ports`.
   - Tìm kiếm thanh ghi Watchpoint/Breakpoint tĩnh từ lõi CPU (`arm_debug_state64_t`).
   - Kiểm tra giao diện Terminal ảo `isatty(STDOUT_FILENO)` của LLDB.
   - Luồng chạy ngầm (Watchdog Thread) kiểm tra liên tục, ẩn qua Dynamic API Resolution (`dlsym` động).
4. **Anti-Dump (`AntiDump.h/.mm`)**: Phá hủy dữ liệu Mach-O header, lấp đầy bảng Symbol Table (`LC_SYMTAB`) bằng số 0, và làm hỏng tên Load Command trong Memory đẻ ngăn ngừa dump bằng bfinject / flexdecrypt.
5. **Anti-Hooking (`AntiHook.h/.mm`)** (Extreme Security): 
   - Kiểm tra 16 instruction (64-bytes) đầu tiên để dò nhánh rẽ `B`, `BR`, `LDR PC`, `ADRP` của các Trampoline ngầm.
   - Quét sự thay đổi dylib nguồn bằng lệnh `dladdr`, theo vết mọi con trỏ trượt về Substrate, Frida, ElleKit, Dobby, Fishhook.
6. **Anti-Decryption (`AntiDecryption.h/.mm`)**: Từ chối hoạt động nếu Host App (ứng dụng mục tiêu) đã bị Crack (mất cờ bảo vệ DRM `cryptid == 0`). Rất hữu ích chặn Tweak lậu chạy chung với iPA lậu.
7. **Anti-Environment (`AntiEnvironment.h/.mm`)**: Quét vật lý File System bằng **Direct Syscalls (SVC #0x80)** để dò tìm mọi dấu hiệu từ Rootful (Checkra1n, unc0ver) đến Rootless (Dopamine, roothide) và Sideload (TrollStore, TrollInstallerX). Chặn `DYLD_INSERT_LIBRARIES` và Sandbox Escape.
8. **Anti-Tamper (`AntiTamper.h/.mm`) [MỚI]**: Tính toán mã băm (SHA-256 Checksum) của toàn bộ phân vùng `__TEXT` (chứa mã máy) lúc khởi động. Một Watchdog Thread chạy ngầm liên tục kiểm tra lại Hash để chống các cuộc tấn công vá bộ nhớ trên RAM (Memory Patching / Hex Editing).

> **LƯU Ý:** Toàn bộ các module nhạy cảm đều được bảo vệ thêm bởi **Bogus Control Flow** (Chèn mã rác Assembly `OBF_JUNK_CODE`) làm hỏng khả năng phân tích và vẽ graph tĩnh của IDA Pro (Lỗi Decompilation Failure).

## Cấu trúc thư mục
```text
├── include/                   
│   ├── AntiDebug.h
│   ├── AntiDump.h
│   ├── AntiHook.h
│   ├── AntiDecryption.h       
│   ├── AntiEnvironment.h
│   ├── AntiTamper.h           
│   ├── ObjCObfuscation.h
│   ├── ObfuscateModule.h      # Umbrella Header nạp mọi thứ bằng Cờ (Flags)
│   └── StringObfuscation.hpp
└── src/                       
    ├── AntiDebug.mm
    ├── AntiDump.mm
    ├── AntiHook.mm
    ├── AntiDecryption.mm      
    ├── AntiEnvironment.mm
    ├── AntiTamper.mm     
    └── ObjCObfuscation.mm
```

## Hướng dẫn cài đặt vào dự án Theos

1. Copy toàn bộ thư mục `include` và `src` vào dự án Theos của bạn.
2. Sửa file `Makefile` của tweak, add flag vào Compiler và thêm các file resource:
```makefile
TARGET = iphone:clang:latest:14.0

TWEAK_NAME = MyTweak
MyTweak_FILES = Tweak.x src/AntiDebug.mm src/AntiDump.mm src/AntiHook.mm src/ObjCObfuscation.mm src/AntiDecryption.mm src/AntiEnvironment.mm src/AntiTamper.mm
MyTweak_CFLAGS = -fobjc-arc -I./include -std=c++14

include $(THEOS_MAKE_PATH)/tweak.mk
```
*(Bạn chỉ cần thêm các file `.mm` nào mà bạn thực sự muốn xài vào dòng chứa FILES, nếu lười hoặc tính bật tắt tự động theo flag, hãy quăng hết vào).*

## Hướng dẫn sử dụng

### Lựa chọn 1: Dùng hệ thống cờ (Flags) đi kèm Umbrella Header (Khuyên dùng)
Trước khi import thư viện, hãy define các macro tương ứng. Code nào không được Define sẽ mất tích khi biên dịch.

```objc
#define OBF_USE_ANTI_DEBUG
#define OBF_USE_ANTI_HOOK
#define OBF_USE_ANTI_ENVIRONMENT    // VD: Tôi muốn chặn tất cả thể loại Jailbreak/Sideload
#define OBF_USE_ANTI_DECRYPTION     // VD: Tôi muốn chặn crakers mở Tweak ở app lậu
#define OBF_USE_ANTI_TAMPER         // VD: Chống vá mã trên RAM

#import "ObfuscateModule.h"

%ctor
{
    // 1. Phân tán tập lệnh phòng thủ lên bộ nhớ RAM. Tất cả các Module đã khai báo Flag ở trên sẽ tự kích hoạt ngầm tại lệnh này!
    OBF_INIT_PROTECTIONS();

    // 2. Sử dụng String Encryption giấu chuỗi khỏi file dylib
    NSString *secretAPIUrl = [NSString stringWithUTF8String:OBF_STR("https://my-api.com/verify")];
    
    // 3. Giấu tên Class tĩnh
    Class hiddenClass = OBJC_CLASS("SBLockScreenManager");
}
```

### Lựa chọn 2: Viết mã độc lập kiểu cục bộ (Standalone Module)
Mỗi module đều KHÔNG liên quan đến nhau. Mã rác (Junk Code) và Syscalls đều được nhúng trực tiếp dạng Inline. Bạn hoàn toàn có quyền vứt đi `ObfuscateModule.h` và dùng lẻ bất kỳ file `.h / .mm` nào ở bất cứ đâu.

```objc
#import "AntiEnvironment.h"
#import "ObjCObfuscation.h"

void SomeRandomFunctionCheck()
{
    // Check môi trường bằng Direct Syscalls
    if (ObfIsJailbrokenOrTampered())
    {
        exit(1);
    }
    
    Class stringClass = OBJC_CLASS("NSString");
}
```

## Lưu ý (Disclaimers)
- Các file đều hoạt động độc lập `Header Only + .mm source`.
- `AntiHook.mm`, `AntiTamper.mm`, và các module sử dụng Syscall / Mã rác chuyên dùng hệ ARM64 (Thiết bị thực tế). Sẽ bị bỏ qua hoặc không hỗ trợ tốt ở Simulator x86_64.
- Do việc sử dụng Junk Code và Syscalls trực tiếp cấp thấp, mã nhị phân tạo ra sẽ rất khó khăn để Debug. Hãy cân nhắc vô hiệu hóa các cờ phòng thủ khi đang ở môi trường phát triển (Development).
- Cân nhắc thật kỹ khi dùng `AntiDump` kết hợp xóa Symbol Table ở môi trường Release vì CrashReporter cũng không đọc được Crash Log.
