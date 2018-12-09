# Constants used by the MachO format
# Values & comments are taken from macOS 10.13 headers, adjusted for use in Julia.

# Header 'magic' value constants
const MH_MAGIC = 0xfeedface
const MH_CIGAM = bswap(MH_MAGIC)
const MH_MAGIC_64 = 0xfeedfacf
const MH_CIGAM_64 = bswap(MH_MAGIC_64)
const FAT_MAGIC = 0xcafebabe
const FAT_CIGAM = bswap(FAT_MAGIC)

# Header 'filetype' constants

const  MH_OBJECT = 0x1           # relocatable object file
const  MH_EXECUTE = 0x2          # demand paged executable file
const  MH_FVMLIB = 0x3           # fixed VM shared library file
const  MH_CORE = 0x4             # core file
const  MH_PRELOAD = 0x5          # preloaded executable file
const  MH_DYLIB = 0x6            # dynamically bound shared library
const  MH_DYLINKER = 0x7         # dynamic link editor
const  MH_BUNDLE = 0x8           # dynamically bound bundle file
const  MH_DYLIB_STUB = 0x9       # shared library stub for static
const  MH_DSYM = 0xa             # companion file with only debug
const  MH_KEXT_BUNDLE = 0xb      # x86_64 kexts

# Flags field mach header constants
const MH_NOUNDEFS = 0x1          # the object file has no undefined references
const MH_INCRLINK = 0x2          # the object file is the output of an incremental link against a base file and can't be link edited again
const MH_DYLDLINK = 0x4          # the object file is input for the dynamic linker and can't be staticly link edited again
const MH_BINDATLOAD = 0x8        # the object file's undefined references are bound by the dynamic linker when loaded.
const MH_PREBOUND = 0x10         # the file has its dynamic undefined references prebound. 
const MH_SPLIT_SEGS = 0x20       # the file has its read-only and read-write segments split
const MH_LAZY_INIT = 0x40        # the shared library init routine is to be run lazily via catching memory faults to its writeable segments (obsolete)
const MH_TWOLEVEL = 0x80         # the image is using two-level name space bindings
const MH_FORCE_FLAT = 0x100      # the executable is forcing all images to use flat name space bindings
const MH_NOMULTIDEFS = 0x200     # this umbrella guarantees no multiple defintions of symbols in its sub-images so the two-level namespace hints can always be used.
const MH_NOFIXPREBINDING = 0x400 # do not have dyld notify the prebinding agent about this executable
const MH_PREBINDABLE = 0x800     # the binary is not prebound but can have its prebinding redone. only used when MH_PREBOUND is not set.
const MH_ALLMODSBOUND = 0x1000   # indicates that this binary binds to all two-level namespace modules of its dependent libraries. only used when MH_PREBINDABLE and MH_TWOLEVEL are both set.
const MH_SUBSECTIONS_VIA_SYMBOLS = 0x2000     # safe to divide up the sections into sub-sections via symbols for dead code stripping
const MH_CANONICAL = 0x4000                   # the binary has been canonicalized via the unprebind operation
const MH_WEAK_DEFINES = 0x8000                # the final linked image contains external weak symbols
const MH_BINDS_TO_WEAK = 0x10000              # the final linked image uses weak symbols 
const MH_ALLOW_STACK_EXECUTION = 0x20000      # When this bit is set, all stacks in the task will be given stack execution privilege.  Only used in MH_EXECUTE filetypes.
const MH_ROOT_SAFE = 0x40000                  # When this bit is set, the binary declares it is safe for use in processes with uid zero
const MH_SETUID_SAFE = 0x80000                # When this bit is set, the binary declares it is safe for use in processes when issetugid() is true
const MH_NO_REEXPORTED_DYLIBS = 0x100000      # When this bit is set on a dylib, the static linker does not need to examine dependent dylibs to see if any are re-exported
const MH_PIE = 0x200000                       # When this bit is set, the OS will load the main executable at a random address.  Only used in MH_EXECUTE filetypes.
const MH_DEAD_STRIPPABLE_DYLIB = 0x400000     # Only for use on dylibs.  When linking against a dylib that has this bit set, the static linker will automatically not create a LC_LOAD_DYLIB load command to the dylib if no symbols are being referenced from the dylib.
const MH_HAS_TLV_DESCRIPTORS = 0x800000       # Contains a section of type S_THREAD_LOCAL_VARIABLES
const MH_NO_HEAP_EXECUTION = 0x1000000        # When this bit is set, the OS will run the main executable with a non-executable heap even on platforms (e.g. i386) that don't require it. Only used in MH_EXECUTE filetypes.
const MH_APP_EXTENSION_SAFE = 0x02000000      # The code was linked for use in an application extension.

# Constants for the cmd field of all load commands
# Or'd into following load commands where the dy-linker needs to understand the load command for execution.
# See mach-o/loader.h for more details.
const LC_REQ_DYLD = 0x80000000 
const LC_SEGMENT = 0x1              # segment of this file to be mapped
const LC_SYMTAB = 0x2               # link-edit stab symbol table info
const LC_SYMSEG = 0x3               # link-edit gdb symbol table info (obsolete)
const LC_THREAD = 0x4               # thread
const LC_UNIXTHREAD = 0x5           # unix thread (includes a stack)
const LC_LOADFVMLIB = 0x6           # load a specified fixed VM shared library
const LC_IDFVMLIB = 0x7             # fixed VM shared library identification
const LC_IDENT = 0x8                # object identification info (obsolete)
const LC_FVMFILE = 0x9              # fixed VM file inclusion (internal use)
const LC_PREPAGE = 0xa              # prepage command (internal use)
const LC_DYSYMTAB = 0xb             # dynamic link-edit symbol table info
const LC_LOAD_DYLIB = 0xc           # load a dynamically linked shared library
const LC_ID_DYLIB = 0xd             # dynamically linked shared lib ident
const LC_LOAD_DYLINKER = 0xe        # load a dynamic linker
const LC_ID_DYLINKER = 0xf          # dynamic linker identification
const LC_PREBOUND_DYLIB = 0x10      # modules prebound for a dynamically linked shared library
const LC_ROUTINES = 0x11           # image routines
const LC_SUB_FRAMEWORK = 0x12      # sub framework
const LC_SUB_UMBRELLA = 0x13       # sub umbrella
const LC_SUB_CLIENT = 0x14         # sub client
const LC_SUB_LIBRARY = 0x15        # sub library
const LC_TWOLEVEL_HINTS = 0x16     # two-level namespace lookup hints
const LC_PREBIND_CKSUM = 0x17      # prebind checksum
const LC_LOAD_WEAK_DYLIB = (0x18 | LC_REQ_DYLD)   # load a dynamically linked shared library that is allowed to be missing (all symbols are weak imported).
const LC_SEGMENT_64 = 0x19                        # 64-bit segment of this file to be mapped
const LC_ROUTINES_64 = 0x1a                       # 64-bit image routines
const LC_UUID = 0x1b                              # the uuid
const LC_RPATH = (0x1c | LC_REQ_DYLD)             # runpath additions
const LC_CODE_SIGNATURE = 0x1d                    # local of code signature
const LC_SEGMENT_SPLIT_INFO = 0x1e                # local of info to split segments
const LC_REEXPORT_DYLIB = (0x1f | LC_REQ_DYLD)    # load and re-export dylib
const LC_LAZY_LOAD_DYLIB = 0x20                   # delay load of dylib until first use
const LC_ENCRYPTION_INFO = 0x21                   # encrypted segment information
const LC_DYLD_INFO = 0x22                         # compressed dyld information
const LC_DYLD_INFO_ONLY = (0x22|LC_REQ_DYLD)      # compressed dyld information only
const LC_LOAD_UPWARD_DYLIB = (0x23 | LC_REQ_DYLD) # load upward dylib
const LC_VERSION_MIN_MACOSX = 0x24                # build for MacOSX min OS version
const LC_VERSION_MIN_IPHONEOS = 0x25              # build for iPhoneOS min OS version
const LC_FUNCTION_STARTS = 0x26                   # compressed table of function start addresses
const LC_DYLD_ENVIRONMENT = 0x27                  # string for dyld to treat like environment variable
const LC_MAIN = (0x28|LC_REQ_DYLD)                # replacement for LC_UNIXTHREAD
const LC_DATA_IN_CODE = 0x29                      # table of non-instructions in __text
const LC_SOURCE_VERSION = 0x2A                    # source version used to build binary
const LC_DYLIB_CODE_SIGN_DRS = 0x2B               # Code signing DRs copied from linked dylibs
const LC_ENCRYPTION_INFO_64 = 0x2C                # 64-bit encrypted segment information
const LC_LINKER_OPTION = 0x2D                     # linker options in MH_OBJECT files
const LC_LINKER_OPTIMIZATION_HINT = 0x2E          # optimization hints in MH_OBJECT files
const LC_VERSION_MIN_TVOS = 0x2F                  # build for AppleTV min OS version
const LC_VERSION_MIN_WATCHOS = 0x30               # build for Watch min OS version
const LC_NOTE = 0x31                              # arbitrary data included within a Mach-O file
const LC_BUILD_VERSION = 0x32                     # build for platform min OS version