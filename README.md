# jmo 
[![Build Status](https://dev.azure.com/danielbeard0/danielbeard0/_apis/build/status/daniel-beard.jmo?branchName=master)](https://dev.azure.com/danielbeard0/danielbeard0/_build/latest?definitionId=3&branchName=master)

Julia MachO file parser. Very experimental, do not use in production anywhere for now.
I'm adding new commands as I require them.

## Usage

```
$ julia src/jmo.jl --help                             
usage: jmo.jl [-h] [-a ARCH] [--archs] [-c] [-L] [--objc-classes]
              [--disassemble] [--min-sdk] [--uuid] [--binding-opcodes]
              [--help] [--version] file

MachO object file viewer

positional arguments:
  file               File to read

optional arguments:
  -h, --header       display header
  -a, --arch ARCH    select an architecture for fat files
  --archs            print architectures
  -c, --ls           show load commands summary
  -L, --shared-libs  show names and version numbers of the shared
                     libraries that the object file uses.
  --objc-classes     lists names of objective-c classes that exist in
                     the object file
  --disassemble      Disassemble the __TEXT section
  --min-sdk          Show the deployment target the binary was
                     compiled for
  --uuid             Print the 128-bit UUID for an image or its
                     corresponding dSYM file.
  --binding-opcodes  Shows binding info op codes
  --help             Show help
  --version          show version information and exit
```

## Usage Examples

'-h display header'

```
$ julia src/jmo.jl -h ~/xip
MachHeader64
+------------+-----------------+------------------------+------------+-------+------------+--------------------------------------------+
|   magic    |     cputype     |       cpusubtype       |  filetype  | ncmds | sizeofcmds |                   flags                    |
+============+=================+========================+============+=======+============+============================================+
| 0xfeedfacf | CPU_TYPE_X86_64 | CPU_SUBTYPE_X86_64_ALL | MH_EXECUTE |  21   |    2488    | MH_DYLDLINK|MH_NOUNDEFS|MH_PIE|MH_TWOLEVEL |
+------------+-----------------+------------------------+------------+-------+------------+--------------------------------------------+
```

'--ls show load commands summary'

```
$ julia src/jmo.jl --ls ~/xip
Load Commands:
LC_SEGMENT_64
LC_SEGMENT_64
LC_SEGMENT_64
LC_SEGMENT_64
LC_DYLD_INFO_ONLY
LC_SYMTAB
LC_DYSYMTAB
LC_LOAD_DYLINKER
LC_UUID
LC_BUILD_VERSION
LC_SOURCE_VERSION
LC_MAIN
LC_LOAD_DYLIB
LC_LOAD_DYLIB
LC_LOAD_DYLIB
LC_LOAD_DYLIB
LC_LOAD_DYLIB
LC_LOAD_DYLIB
LC_FUNCTION_STARTS
LC_DATA_IN_CODE
LC_CODE_SIGNATURE
```

'-L shared libs example'

```
$ julia src/jmo.jl -L ~/xip
        /System/Library/Frameworks/Security.framework/Versions/A/Security (compatibility version 1.0.0, current version 58286.220.1)
        /System/Library/PrivateFrameworks/PackageKit.framework/Versions/A/PackageKit (compatibility version 1.0.0, current version 434.0.0)
        /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 1555.10.0)
        /usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
        /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1252.200.5)
        /System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 1555.10.0)
```

'--disassemble example'

```
$ julia src/jmo.jl --disassemble Binaries/ObjcThin
0x100000e10:    push            rbp
0x100000e11:    mov             rbp, rsp
0x100000e14:    sub             rsp, 0x10
0x100000e18:    lea             rax, [rip + 0x219]
0x100000e1f:    mov             qword ptr [rbp - 8], rdi
0x100000e23:    mov             qword ptr [rbp - 0x10], rsi
0x100000e27:    mov             rdi, rax
0x100000e2a:    mov             al, 0
0x100000e2c:    call            0x100000ee2
0x100000e31:    lea             rsi, [rip + 0x220]
0x100000e38:    mov             rdi, rsi
0x100000e3b:    mov             al, 0
0x100000e3d:    call            0x100000ee2
0x100000e42:    lea             rsi, [rip + 0x22f]
0x100000e49:    mov             rdi, rsi
0x100000e4c:    mov             al, 0
0x100000e4e:    call            0x100000ee2
0x100000e53:    lea             rsi, [rip + 0x23e]
0x100000e5a:    mov             rdi, rsi
0x100000e5d:    mov             al, 0
0x100000e5f:    call            0x100000ee2
0x100000e64:    add             rsp, 0x10
0x100000e68:    pop             rbp
0x100000e69:    ret
0x100000e6a:    nop             word ptr [rax + rax]
0x100000e70:    push            rbp
0x100000e71:    mov             rbp, rsp
0x100000e74:    sub             rsp, 0x20
0x100000e78:    mov             dword ptr [rbp - 4], 0
0x100000e7f:    mov             dword ptr [rbp - 8], edi
0x100000e82:    mov             qword ptr [rbp - 0x10], rsi
0x100000e86:    call            0x100000eee
0x100000e8b:    mov             rsi, qword ptr [rip + 0x2f6]
0x100000e92:    mov             rcx, qword ptr [rip + 0x2df]
0x100000e99:    mov             rdi, rsi
0x100000e9c:    mov             rsi, rcx
0x100000e9f:    mov             qword ptr [rbp - 0x20], rax
0x100000ea3:    call            qword ptr [rip + 0x167]
0x100000ea9:    mov             qword ptr [rbp - 0x18], rax
0x100000ead:    mov             rax, qword ptr [rbp - 0x18]
0x100000eb1:    mov             rsi, qword ptr [rip + 0x2c8]
0x100000eb8:    mov             rdi, rax
0x100000ebb:    call            qword ptr [rip + 0x14f]
0x100000ec1:    xor             edx, edx
0x100000ec3:    mov             esi, edx
0x100000ec5:    lea             rax, [rbp - 0x18]
0x100000ec9:    mov             rdi, rax
0x100000ecc:    call            0x100000ef4
0x100000ed1:    mov             rdi, qword ptr [rbp - 0x20]
0x100000ed5:    call            0x100000ee8
0x100000eda:    xor             eax, eax
0x100000edc:    add             rsp, 0x20
0x100000ee0:    pop             rbp
0x100000ee1:    ret
Ptr{Nothing} @0x0000000121493100
```

'--uuid example'

```
$ julia src/jmo.jl --uuid ~/ObjcThin
LC_UUID:
07DF0928-1403-37A6-9B9B-7186FA400CBB
```

'--min-sdk example'

```
$ julia src/jmo.jl --min-sdk ~/ObjcThin
LC_VERSION_MIN_MACOSX
Loaded version min: 658688 658944
version: 10.13.0
sdk: 10.14.0
```

'--binding-opcodes example'

```
$ julia src/jmo.jl --binding-opcodes ~/ObjcThin
Binding info 0x00002018 - 0x000020e0
0x0001 BIND_OPCODE_SET_DYLIB_ORDINAL_IMM(2)
0x0002 BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, _OBJC_CLASS_$_NSObject)
0x001a BIND_OPCODE_SET_TYPE_IMM(1)
0x001b BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB(0x02, 0x000001c0)
0x001e BIND_OPCODE_DO_BIND()
0x001f BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, _OBJC_METACLASS_$_NSObject)
0x003b BIND_OPCODE_ADD_ADDR_ULEB(0xffffffffffffffc8)
0x0046 BIND_OPCODE_DO_BIND()
0x0047 BIND_OPCODE_DO_BIND()
0x0048 BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, __objc_empty_cache)
0x005c BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED(0x00000028)
0x005d BIND_OPCODE_DO_BIND()
0x005e BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, _objc_msgSend)
0x006d BIND_OPCODE_ADD_ADDR_ULEB(0xfffffffffffffe40)
0x0078 BIND_OPCODE_DO_BIND()
0x0079 BIND_OPCODE_SET_DYLIB_ORDINAL_IMM(3)
0x007a BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, dyld_stub_binder)
0x008c BIND_OPCODE_ADD_ADDR_ULEB(0xffffffffffffffe8)
0x0097 BIND_OPCODE_DO_BIND()
0x0098 BIND_OPCODE_SET_DYLIB_ORDINAL_IMM(4)
0x0099 BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, ___CFConstantStringClassReference)
0x00bc BIND_OPCODE_ADD_ADDR_ULEB(0x0030)
0x00be BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB(3, 0x00000018)
0x00c1 BIND_OPCODE_DO_BIND()

Lazy binding info 0x000020e0 - 0x00002148
0x0001 BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB(0x02, 0x00000018)
0x0003 BIND_OPCODE_SET_DYLIB_ORDINAL_IMM(1)
0x0004 BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, _NSLog)
0x000c BIND_OPCODE_DO_BIND()
0x000e BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB(0x02, 0x00000020)
0x0010 BIND_OPCODE_SET_DYLIB_ORDINAL_IMM(2)
0x0011 BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, _objc_autoreleasePoolPop)
0x002b BIND_OPCODE_DO_BIND()
0x002d BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB(0x02, 0x00000028)
0x002f BIND_OPCODE_SET_DYLIB_ORDINAL_IMM(2)
0x0030 BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, _objc_autoreleasePoolPush)
0x004b BIND_OPCODE_DO_BIND()
0x004d BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB(0x02, 0x00000030)
0x004f BIND_OPCODE_SET_DYLIB_ORDINAL_IMM(2)
0x0050 BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM(0x00, _objc_storeStrong)
0x0063 BIND_OPCODE_DO_BIND()

Binding Records
description     value
__DATA  0x1000011c0     BIND_TYPE_POINTER       TODO    (libobjc.A.dylib)       _OBJC_CLASS_$_NSObject
__DATA  0x100001190     BIND_TYPE_POINTER       TODO    (libobjc.A.dylib)       _OBJC_METACLASS_$_NSObject
__DATA  0x100001198     BIND_TYPE_POINTER       TODO    (libobjc.A.dylib)       _OBJC_METACLASS_$_NSObject
__DATA  0x1000011a0     BIND_TYPE_POINTER       TODO    (libobjc.A.dylib)       __objc_empty_cache
__DATA  0x1000011c8     BIND_TYPE_POINTER       TODO    (libobjc.A.dylib)       __objc_empty_cache
__DATA  0x100001010     BIND_TYPE_POINTER       TODO    (libobjc.A.dylib)       _objc_msgSend
__DATA  0x100001000     BIND_TYPE_POINTER       TODO    (libSystem.B.dylib)     dyld_stub_binder
__DATA  0x100001038     BIND_TYPE_POINTER       TODO    (CoreFoundation)        ___CFConstantStringClassReference
__DATA  0x100001058     BIND_TYPE_POINTER       TODO    (CoreFoundation)        ___CFConstantStringClassReference
__DATA  0x100001078     BIND_TYPE_POINTER       TODO    (CoreFoundation)        ___CFConstantStringClassReference
__DATA  0x100001098     BIND_TYPE_POINTER       TODO    (CoreFoundation)        ___CFConstantStringClassReference

Lazy Binding Records
description     value
__DATA  0x100001018     (Foundation)    _NSLog
__DATA  0x100001020     (libobjc.A.dylib)       _objc_autoreleasePoolPop
__DATA  0x100001028     (libobjc.A.dylib)       _objc_autoreleasePoolPush
__DATA  0x100001030     (libobjc.A.dylib)       _objc_storeStrong
```
