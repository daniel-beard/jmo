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
  --objc-header-dump  Outputs a list of classes and their method names
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
