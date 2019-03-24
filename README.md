# jmo 
[![Build Status](https://dev.azure.com/danielbeard0/danielbeard0/_apis/build/status/daniel-beard.jmo?branchName=master)](https://dev.azure.com/danielbeard0/danielbeard0/_build/latest?definitionId=3&branchName=master)

Julia MachO file parser. Very experimental, do not use in production anywhere for now.
I'm adding new commands as I require them.

## Usage

```
$ julia src/jmo.jl --help
usage: jmo.jl [--help] [-h] [-c] [-L] [--objc-classes]
              [--objc-header-dump] [--version] file

MachO object file viewer

positional arguments:
  file                File to read

optional arguments:
  --help
  -h, --header        display header
  -c, --ls            show load commands summary
  -L, --shared-libs   show names and version numbers of the shared
                      libraries that the object file uses.
  --objc-classes      lists names of objective-c classes that exist in
                      the object file
  --disassemble       Disassemble the __TEXT section
  --version           show version information and exit
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
