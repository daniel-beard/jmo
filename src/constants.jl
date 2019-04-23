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

# Hacky macro that converts a vect to a dictionary
# Can probably break in a number of ways, as this is the first julia macro I've ever written :O
# E.g. d = @dict[MH_OBJECT, MH_EXECUTE]
# Becomes: Dict(([MH_OBJECT, "MH_OBJECT"]), (MH_EXECUTE, "MH_EXECUTE")])
macro dict(x)
  # Uncomment for debugging
  # dump(x.head); dump(x.args)
  # println(string(x.args[1]))
  if x.head == :vect 
    local tups = map(i -> (eval(i), string(i)) , x.args)
    return Expr(:call, Dict, Expr(:tuple, tups...))
  end
end

header_filetypes = @dict[MH_OBJECT, MH_EXECUTE, MH_FVMLIB, MH_CORE, MH_PRELOAD, MH_DYLIB,
                    MH_DYLINKER, MH_BUNDLE, MH_DYLIB_STUB, MH_DSYM, MH_KEXT_BUNDLE]

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

header_flags = @dict[MH_NOUNDEFS, MH_INCRLINK, MH_DYLDLINK, MH_BINDATLOAD, MH_PREBOUND, MH_SPLIT_SEGS, MH_LAZY_INIT, MH_TWOLEVEL, MH_FORCE_FLAT,
                MH_NOMULTIDEFS, MH_NOFIXPREBINDING, MH_PREBINDABLE, MH_ALLMODSBOUND, MH_SUBSECTIONS_VIA_SYMBOLS, MH_CANONICAL, MH_WEAK_DEFINES,
                MH_BINDS_TO_WEAK, MH_ALLOW_STACK_EXECUTION, MH_ROOT_SAFE, MH_SETUID_SAFE, MH_NO_REEXPORTED_DYLIBS, MH_PIE, MH_DEAD_STRIPPABLE_DYLIB,
                MH_HAS_TLV_DESCRIPTORS, MH_NO_HEAP_EXECUTION, MH_APP_EXTENSION_SAFE]

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

load_commands = @dict[LC_SEGMENT, LC_SYMTAB, LC_SYMSEG, LC_THREAD, LC_UNIXTHREAD, LC_LOADFVMLIB, LC_IDFVMLIB, LC_IDENT, 
  LC_FVMFILE, LC_PREPAGE, LC_DYSYMTAB, LC_LOAD_DYLIB, LC_ID_DYLIB, LC_LOAD_DYLINKER, LC_ID_DYLINKER, LC_PREBOUND_DYLIB, 
  LC_ROUTINES, LC_SUB_FRAMEWORK, LC_SUB_UMBRELLA, LC_SUB_CLIENT, LC_SUB_LIBRARY, LC_TWOLEVEL_HINTS, LC_PREBIND_CKSUM, 
  LC_LOAD_WEAK_DYLIB, LC_SEGMENT_64, LC_ROUTINES_64, LC_UUID, LC_RPATH, LC_CODE_SIGNATURE, LC_SEGMENT_SPLIT_INFO, 
  LC_REEXPORT_DYLIB, LC_LAZY_LOAD_DYLIB, LC_ENCRYPTION_INFO, LC_DYLD_INFO, LC_DYLD_INFO_ONLY, LC_LOAD_UPWARD_DYLIB, 
  LC_VERSION_MIN_MACOSX, LC_VERSION_MIN_IPHONEOS, LC_FUNCTION_STARTS, LC_DYLD_ENVIRONMENT, LC_MAIN, LC_DATA_IN_CODE, 
  LC_SOURCE_VERSION, LC_DYLIB_CODE_SIGN_DRS, LC_ENCRYPTION_INFO_64, LC_LINKER_OPTION, LC_LINKER_OPTIMIZATION_HINT, 
  LC_VERSION_MIN_TVOS, LC_VERSION_MIN_WATCHOS, LC_NOTE, LC_BUILD_VERSION]

# The flags field of a section structure is separated into two parts a section
# type and section attributes.  The section types are mutually exclusive (it
# can only have one type) but the section attributes are not (it may have more
# than one attribute).
const SECTION_TYPE       = 0x000000ff # 256 section types
const SECTION_ATTRIBUTES = 0xffffff00 # 24 section attributes

# Constants for the type of a section 
const S_REGULAR           = 0x0 # regular section
const S_ZEROFILL          = 0x1 # zero fill on demand section
const S_CSTRING_LITERALS  = 0x2 # section with only literal C strings
const S_4BYTE_LITERALS    = 0x3 # section with only 4 byte literals
const S_8BYTE_LITERALS    = 0x4 # section with only 8 byte literals
const S_LITERAL_POINTERS  = 0x5 # section with only pointers to literals

# For the two types of symbol pointers sections and the symbol stubs section
# they have indirect symbol table entries.  For each of the entries in the
# section the indirect symbol table entries, in corresponding order in the
# indirect symbol table, start at the index stored in the reserved1 field
# of the section structure.  Since the indirect symbol table entries
# correspond to the entries in the section the number of indirect symbol table
# entries is inferred from the size of the section divided by the size of the
# entries in the section.  For symbol pointers sections the size of the entries
# in the section is 4 bytes and for symbol stubs sections the byte size of the
# stubs is stored in the reserved2 field of the section structure.

const S_NON_LAZY_SYMBOL_POINTERS    = 0x6 # section with only non-lazy symbol pointers
const S_LAZY_SYMBOL_POINTERS        = 0x7 # section with only lazy symbol pointers
const S_SYMBOL_STUBS                = 0x8 # section with only symbol stubs, byte size of stub in the reserved2 field
const S_MOD_INIT_FUNC_POINTERS      = 0x9 # section with only function pointers for initialization
const S_MOD_TERM_FUNC_POINTERS      = 0xa # section with only function pointers for termination
const S_COALESCED                   = 0xb # section contains symbols that are to be coalesced
const S_GB_ZEROFILL                 = 0xc # zero fill on demand section (that can be larger than 4 gigabytes)
const S_INTERPOSING                 = 0xd # section with only pairs of function pointers for interposing
const S_16BYTE_LITERALS             = 0xe # section with only 16 byte literals
const S_DTRACE_DOF                  = 0xf # section contains DTrace Object Format
const S_LAZY_DYLIB_SYMBOL_POINTERS  = 0x10 # section with only lazy symbol pointers to lazy loaded dylibs
# Section types to support thread local variables
const S_THREAD_LOCAL_REGULAR                = 0x11  # template of initial  values for TLVs
const S_THREAD_LOCAL_ZEROFILL               = 0x12  # template of initial values for TLVs
const S_THREAD_LOCAL_VARIABLES              = 0x13  # TLV descriptors
const S_THREAD_LOCAL_VARIABLE_POINTERS      = 0x14  # pointers to TLV descriptors
const S_THREAD_LOCAL_INIT_FUNCTION_POINTERS = 0x15  # functions to call to initialize TLV values

section_types = @dict[S_REGULAR, S_ZEROFILL, S_CSTRING_LITERALS, S_4BYTE_LITERALS, S_8BYTE_LITERALS, S_LITERAL_POINTERS,
                     S_NON_LAZY_SYMBOL_POINTERS, S_LAZY_SYMBOL_POINTERS, S_SYMBOL_STUBS, S_MOD_INIT_FUNC_POINTERS, 
                     S_MOD_TERM_FUNC_POINTERS, S_COALESCED, S_GB_ZEROFILL, S_INTERPOSING, S_16BYTE_LITERALS, S_DTRACE_DOF,
                     S_LAZY_DYLIB_SYMBOL_POINTERS, S_THREAD_LOCAL_REGULAR, S_THREAD_LOCAL_VARIABLES, S_THREAD_LOCAL_VARIABLE_POINTERS,
                     S_THREAD_LOCAL_INIT_FUNCTION_POINTERS]

# Constants for the section attributes part of the flags field of a section structure.
const SECTION_ATTRIBUTES_USR        = 0xff000000 # User setable attributes
const S_ATTR_PURE_INSTRUCTIONS      = 0x80000000 # section contains only true machine instructions
const S_ATTR_NO_TOC                 = 0x40000000 # section contains coalesced symbols that are not to be in a ranlib table of contents
const S_ATTR_STRIP_STATIC_SYMS      = 0x20000000 # ok to strip static symbols in this section in files with the MH_DYLDLINK flag
const S_ATTR_NO_DEAD_STRIP          = 0x10000000 # no dead stripping
const S_ATTR_LIVE_SUPPORT           = 0x08000000 # blocks are live if they reference live blocks
const S_ATTR_SELF_MODIFYING_CODE    = 0x04000000 # Used with i386 code stubs written on by dyld

# If a segment contains any sections marked with S_ATTR_DEBUG then all
# sections in that segment must have this attribute.  No section other than
# a section marked with this attribute may reference the contents of this
# section.  A section with this attribute may contain no symbols and must have
# a section type S_REGULAR.  The static linker will not copy section contents
# from sections with this attribute into its output file.  These sections
# generally contain DWARF debugging info.
const S_ATTR_DEBUG                  = 0x02000000 # a debug section
const SECTION_ATTRIBUTES_SYS        = 0x00ffff00 # system setable attributes
const S_ATTR_SOME_INSTRUCTIONS      = 0x00000400 # section contains some machine instructions
const S_ATTR_EXT_RELOC              = 0x00000200 # section has external relocation entries
const S_ATTR_LOC_RELOC              = 0x00000100 # section has local relocation entries

# Note: SECTION_ATTRIBUTES_USR && SECTION_ATTRIBUTES_SYS are not included, as they are sub-masks. Not used right now.
section_attributes = @dict[S_ATTR_PURE_INSTRUCTIONS, S_ATTR_NO_TOC, S_ATTR_STRIP_STATIC_SYMS, S_ATTR_NO_DEAD_STRIP,
                          S_ATTR_LIVE_SUPPORT, S_ATTR_SELF_MODIFYING_CODE, S_ATTR_DEBUG, S_ATTR_SOME_INSTRUCTIONS, 
                          S_ATTR_EXT_RELOC, S_ATTR_LOC_RELOC]


# machine constants (like CPU type)
# TODO: Can't mark these as CPUType until the following is resolved:
#   -> syntax: type declarations on global variables are not yet supported
const CPUType = Int32

# Capability bits used in the definition of cpu_type.
const CPU_ARCH_MASK           = 0xff000000      # mask for architecture bits
const CPU_ARCH_ABI64          = 0x01000000      # 64 bit ABI
const CPU_ARCH_ABI64_32       = 0x02000000      # ABI for 64-bit hardware with 32-bit types; LP32

# Machine types known by all.
const CPU_TYPE_ANY            = -1
const CPU_TYPE_VAX            = 1
# skip 2::CPUType
# skip 3::CPUType
# skip 4::CPUType
# skip 5::CPUType
const CPU_TYPE_MC680x0        = 6
const CPU_TYPE_X86            = 7
const CPU_TYPE_I386           = CPU_TYPE_X86                  # compatibility
const CPU_TYPE_X86_64         = (CPU_TYPE_X86 | CPU_ARCH_ABI64)
# skip CPU_TYPE_MIPS  8::CPUType
# skip                9::CPUType
const CPU_TYPE_MC98000        = 10
const CPU_TYPE_HPPA           = 11
const CPU_TYPE_ARM            = 12
const CPU_TYPE_ARM64          = (CPU_TYPE_ARM | CPU_ARCH_ABI64)
const CPU_TYPE_ARM64_32       = (CPU_TYPE_ARM | CPU_ARCH_ABI64_32)
const CPU_TYPE_MC88000        = 13
const CPU_TYPE_SPARC          = 14
const CPU_TYPE_I860           = 15
# skip CPU_TYPE_ALPHA 16::CPUType
# skip 17::CPUType
const CPU_TYPE_POWERPC        = 18
const CPU_TYPE_POWERPC64      = (CPU_TYPE_POWERPC | CPU_ARCH_ABI64)

cpu_types = @dict[CPU_TYPE_ANY, CPU_TYPE_VAX, CPU_TYPE_MC680x0, CPU_TYPE_X86, CPU_TYPE_I386, CPU_TYPE_X86_64,
                  CPU_TYPE_MC98000, CPU_TYPE_HPPA, CPU_TYPE_ARM, CPU_TYPE_ARM64, CPU_TYPE_ARM64_32, 
                  CPU_TYPE_MC88000, CPU_TYPE_SPARC, CPU_TYPE_I860, CPU_TYPE_POWERPC, CPU_TYPE_POWERPC64]


# CPU subtypes

# TODO: Can't mark these as CPUSubType until the following is resolved:
#   -> syntax: type declarations on global variables are not yet supported
const CPUSubType = Int32

# Capability bits used in the definition of cpu_subtype.
const CPU_SUBTYPE_MASK       = 0xff000000      # mask for feature flags
const CPU_SUBTYPE_LIB64      = 0x80000000      # 64 bit libraries

# Object files that are hand-crafted to run on any implementation of an architecture are tagged with CPU_SUBTYPE_MULTIPLE.  This functions essentially the same as
# the "ALL" subtype of an architecture except that it allows us to easily find object files that may need to be modified whenever a new implementation of an architecture comes out.
# It is the responsibility of the implementor to make sure the software handles unsupported implementations elegantly.
const CPU_SUBTYPE_MULTIPLE            = -1
const CPU_SUBTYPE_LITTLE_ENDIAN       = 0
const CPU_SUBTYPE_BIG_ENDIAN          = 1

# Machine threadtypes. This is none - not defined - for most machine types/subtypes.
const CPU_THREADTYPE_NONE             = 0 # cpu_threadtype_t

#VAX subtypes (these do *not* necessary conform to the actual cpu ID assigned by DEC available via the SID register).
const CPU_SUBTYPE_VAX_ALL     = 0
const CPU_SUBTYPE_VAX780      = 1
const CPU_SUBTYPE_VAX785      = 2
const CPU_SUBTYPE_VAX750      = 3
const CPU_SUBTYPE_VAX730      = 4
const CPU_SUBTYPE_UVAXI       = 5
const CPU_SUBTYPE_UVAXII      = 6
const CPU_SUBTYPE_VAX8200     = 7
const CPU_SUBTYPE_VAX8500     = 8
const CPU_SUBTYPE_VAX8600     = 9
const CPU_SUBTYPE_VAX8650     = 10
const CPU_SUBTYPE_VAX8800     = 11
const CPU_SUBTYPE_UVAXIII     = 12

cpu_subtypes_vax = @dict[ CPU_SUBTYPE_VAX_ALL, CPU_SUBTYPE_VAX780, CPU_SUBTYPE_VAX785, CPU_SUBTYPE_VAX750, CPU_SUBTYPE_VAX730, CPU_SUBTYPE_UVAXI,
  CPU_SUBTYPE_UVAXII, CPU_SUBTYPE_VAX8200, CPU_SUBTYPE_VAX8500, CPU_SUBTYPE_VAX8600, CPU_SUBTYPE_VAX8650, CPU_SUBTYPE_VAX8800, CPU_SUBTYPE_UVAXIII]

# 680x0 subtypes
# The subtype definitions here are unusual for historical reasons. NeXT used to consider 68030 code as generic 68000 code. For backwards compatability:
# CPU_SUBTYPE_MC68030 symbol has been preserved for source code compatability.
# CPU_SUBTYPE_MC680x0_ALL has been defined to be the same subtype as CPU_SUBTYPE_MC68030 for binary comatability.
# CPU_SUBTYPE_MC68030_ONLY has been added to allow new object files to be tagged as containing 68030-specific instructions.

const CPU_SUBTYPE_MC680x0_ALL         = 1
const CPU_SUBTYPE_MC68030             = 1 # compat
const CPU_SUBTYPE_MC68040             = 2
const CPU_SUBTYPE_MC68030_ONLY        = 3

cpu_subtypes_mc680 = @dict[CPU_SUBTYPE_MC680x0_ALL, CPU_SUBTYPE_MC68030, CPU_SUBTYPE_MC68040, CPU_SUBTYPE_MC68030_ONLY]

# I386 subtypes

CPU_SUBTYPE_INTEL(f, m) = ((f) + ((m) << 4))

const CPU_SUBTYPE_I386_ALL        = CPU_SUBTYPE_INTEL(3, 0)
const CPU_SUBTYPE_386             = CPU_SUBTYPE_INTEL(3, 0)
const CPU_SUBTYPE_486             = CPU_SUBTYPE_INTEL(4, 0)
const CPU_SUBTYPE_486SX           = CPU_SUBTYPE_INTEL(4, 8) # 8 << 4 = 128
const CPU_SUBTYPE_586             = CPU_SUBTYPE_INTEL(5, 0)
const CPU_SUBTYPE_PENT            = CPU_SUBTYPE_INTEL(5, 0)
const CPU_SUBTYPE_PENTPRO         = CPU_SUBTYPE_INTEL(6, 1)
const CPU_SUBTYPE_PENTII_M3       = CPU_SUBTYPE_INTEL(6, 3)
const CPU_SUBTYPE_PENTII_M5       = CPU_SUBTYPE_INTEL(6, 5)
const CPU_SUBTYPE_CELERON         = CPU_SUBTYPE_INTEL(7, 6)
const CPU_SUBTYPE_CELERON_MOBILE  = CPU_SUBTYPE_INTEL(7, 7)
const CPU_SUBTYPE_PENTIUM_3       = CPU_SUBTYPE_INTEL(8, 0)
const CPU_SUBTYPE_PENTIUM_3_M     = CPU_SUBTYPE_INTEL(8, 1)
const CPU_SUBTYPE_PENTIUM_3_XEON  = CPU_SUBTYPE_INTEL(8, 2)
const CPU_SUBTYPE_PENTIUM_M       = CPU_SUBTYPE_INTEL(9, 0)
const CPU_SUBTYPE_PENTIUM_4       = CPU_SUBTYPE_INTEL(10, 0)
const CPU_SUBTYPE_PENTIUM_4_M     = CPU_SUBTYPE_INTEL(10, 1)
const CPU_SUBTYPE_ITANIUM         = CPU_SUBTYPE_INTEL(11, 0)
const CPU_SUBTYPE_ITANIUM_2       = CPU_SUBTYPE_INTEL(11, 1)
const CPU_SUBTYPE_XEON            = CPU_SUBTYPE_INTEL(12, 0)
const CPU_SUBTYPE_XEON_MP         = CPU_SUBTYPE_INTEL(12, 1)

CPU_SUBTYPE_INTEL_FAMILY(x)             = ((x) & 15)
const CPU_SUBTYPE_INTEL_FAMILY_MAX      = 15

CPU_SUBTYPE_INTEL_MODEL(x)              = ((x) >> 4)
const CPU_SUBTYPE_INTEL_MODEL_ALL       = 0

cpu_subtypes_i386 = @dict[
  CPU_SUBTYPE_I386_ALL, CPU_SUBTYPE_386, CPU_SUBTYPE_486, CPU_SUBTYPE_486SX, CPU_SUBTYPE_586, CPU_SUBTYPE_PENT, 
  CPU_SUBTYPE_PENTPRO, CPU_SUBTYPE_PENTII_M3, CPU_SUBTYPE_PENTII_M5, CPU_SUBTYPE_CELERON, CPU_SUBTYPE_CELERON_MOBILE, 
  CPU_SUBTYPE_PENTIUM_3, CPU_SUBTYPE_PENTIUM_3_M, CPU_SUBTYPE_PENTIUM_3_XEON, CPU_SUBTYPE_PENTIUM_M, CPU_SUBTYPE_PENTIUM_4, 
  CPU_SUBTYPE_PENTIUM_4_M, CPU_SUBTYPE_ITANIUM, CPU_SUBTYPE_ITANIUM_2, CPU_SUBTYPE_XEON, CPU_SUBTYPE_XEON_MP]

# X86 subtypes.
const CPU_SUBTYPE_X86_ALL            = 3
const CPU_SUBTYPE_X86_64_ALL         = 3
const CPU_SUBTYPE_X86_ARCH1          = 4
const CPU_SUBTYPE_X86_64_H           = 8      # Haswell feature subset

cpu_subtypes_x86_64 = @dict[CPU_SUBTYPE_X86_ALL, CPU_SUBTYPE_X86_64_ALL, CPU_SUBTYPE_X86_ARCH1, CPU_SUBTYPE_X86_64_H]

const CPU_THREADTYPE_INTEL_HTT       = 1 # cpu_thread_type_t

# Mips subtypes.
const CPU_SUBTYPE_MIPS_ALL    =  0
const CPU_SUBTYPE_MIPS_R2300  =  1
const CPU_SUBTYPE_MIPS_R2600  =  2
const CPU_SUBTYPE_MIPS_R2800  =  3
const CPU_SUBTYPE_MIPS_R2000a =  4     # pmax
const CPU_SUBTYPE_MIPS_R2000  =  5
const CPU_SUBTYPE_MIPS_R3000a =  6     # 3max
const CPU_SUBTYPE_MIPS_R3000  =  7

cpu_subtypes_mips = @dict[CPU_SUBTYPE_MIPS_ALL, CPU_SUBTYPE_MIPS_R2300, CPU_SUBTYPE_MIPS_R2600, CPU_SUBTYPE_MIPS_R2800, 
  CPU_SUBTYPE_MIPS_R2000a, CPU_SUBTYPE_MIPS_R2000, CPU_SUBTYPE_MIPS_R3000a, CPU_SUBTYPE_MIPS_R3000]

# MC98000 (PowerPC) subtypes
const CPU_SUBTYPE_MC98000_ALL = 0
const CPU_SUBTYPE_MC98601     = 1

cpu_subtypes_mc98000 = @dict[CPU_SUBTYPE_MC98000_ALL, CPU_SUBTYPE_MC98601]

# HPPA subtypes for Hewlett-Packard HP-PA family of risc processors. Port by NeXT to 700 series.
const CPU_SUBTYPE_HPPA_ALL     = 0
const CPU_SUBTYPE_HPPA_7100    = 0 # compat
const CPU_SUBTYPE_HPPA_7100LC  = 1

cpu_subtypes_hppa = @dict[CPU_SUBTYPE_HPPA_ALL, CPU_SUBTYPE_HPPA_7100, CPU_SUBTYPE_HPPA_7100LC]

# MC88000 subtypes.
const CPU_SUBTYPE_MC88000_ALL =  0
const CPU_SUBTYPE_MC88100     =  1
const CPU_SUBTYPE_MC88110     =  2

cpu_subtypes_mc88000 = @dict[CPU_SUBTYPE_MC88000_ALL, CPU_SUBTYPE_MC88100, CPU_SUBTYPE_MC88110]

# SPARC subtypes
const CPU_SUBTYPE_SPARC_ALL   = 0

cpu_subtypes_sparc = @dict[CPU_SUBTYPE_SPARC_ALL]

# I860 subtypes
const CPU_SUBTYPE_I860_ALL    = 0
const CPU_SUBTYPE_I860_860    = 1

cpu_subtypes_i860 = @dict[CPU_SUBTYPE_I860_ALL, CPU_SUBTYPE_I860_860]

# PowerPC subtypes
const CPU_SUBTYPE_POWERPC_ALL    = 0
const CPU_SUBTYPE_POWERPC_601    = 1
const CPU_SUBTYPE_POWERPC_602    = 2
const CPU_SUBTYPE_POWERPC_603    = 3
const CPU_SUBTYPE_POWERPC_603e   = 4
const CPU_SUBTYPE_POWERPC_603ev  = 5
const CPU_SUBTYPE_POWERPC_604    = 6
const CPU_SUBTYPE_POWERPC_604e   = 7
const CPU_SUBTYPE_POWERPC_620    = 8
const CPU_SUBTYPE_POWERPC_750    = 9
const CPU_SUBTYPE_POWERPC_7400   = 10
const CPU_SUBTYPE_POWERPC_7450   = 11
const CPU_SUBTYPE_POWERPC_970    = 100

cpu_subtypes_powerpc = @dict[CPU_SUBTYPE_POWERPC_ALL, CPU_SUBTYPE_POWERPC_601, CPU_SUBTYPE_POWERPC_602, CPU_SUBTYPE_POWERPC_603, 
  CPU_SUBTYPE_POWERPC_603e, CPU_SUBTYPE_POWERPC_603ev, CPU_SUBTYPE_POWERPC_604, CPU_SUBTYPE_POWERPC_604e, CPU_SUBTYPE_POWERPC_620,
  CPU_SUBTYPE_POWERPC_750, CPU_SUBTYPE_POWERPC_7400, CPU_SUBTYPE_POWERPC_7450, CPU_SUBTYPE_POWERPC_970]

# ARM subtypes
const CPU_SUBTYPE_ARM_ALL        = 0
const CPU_SUBTYPE_ARM_V4T        = 5
const CPU_SUBTYPE_ARM_V6         = 6
const CPU_SUBTYPE_ARM_V5TEJ      = 7
const CPU_SUBTYPE_ARM_XSCALE     = 8
const CPU_SUBTYPE_ARM_V7         = 9
const CPU_SUBTYPE_ARM_V7F        = 10 # Cortex A9
const CPU_SUBTYPE_ARM_V7S        = 11 # Swift
const CPU_SUBTYPE_ARM_V7K        = 12
const CPU_SUBTYPE_ARM_V6M        = 14 # Not meant to be run under xnu
const CPU_SUBTYPE_ARM_V7M        = 15 # Not meant to be run under xnu
const CPU_SUBTYPE_ARM_V7EM       = 16 # Not meant to be run under xnu
const CPU_SUBTYPE_ARM_V8         = 13

cpu_subtypes_arm = @dict[CPU_SUBTYPE_ARM_ALL, CPU_SUBTYPE_ARM_V4T, CPU_SUBTYPE_ARM_V6, CPU_SUBTYPE_ARM_V5TEJ, CPU_SUBTYPE_ARM_XSCALE, 
  CPU_SUBTYPE_ARM_V7, CPU_SUBTYPE_ARM_V7F, CPU_SUBTYPE_ARM_V7S, CPU_SUBTYPE_ARM_V7K, CPU_SUBTYPE_ARM_V6M, CPU_SUBTYPE_ARM_V7M, 
  CPU_SUBTYPE_ARM_V7EM, CPU_SUBTYPE_ARM_V8]

# ARM64 subtypes
const CPU_SUBTYPE_ARM64_ALL      = 0
const CPU_SUBTYPE_ARM64_V8       = 1
const CPU_SUBTYPE_ARM64E         = 2

cpu_subtypes_arm64 = @dict[CPU_SUBTYPE_ARM64_ALL, CPU_SUBTYPE_ARM64_V8, CPU_SUBTYPE_ARM64E]

# CPU subtype feature flags for ptrauth on arm64e platforms
const CPU_SUBTYPE_ARM64_PTR_AUTH_MASK = 0x0f000000
CPU_SUBTYPE_ARM64_PTR_AUTH_VERSION(x) = (((x) & CPU_SUBTYPE_ARM64_PTR_AUTH_MASK) >> 24)

#  ARM64_32 subtypes
const CPU_SUBTYPE_ARM64_32_ALL   = 0
const CPU_SUBTYPE_ARM64_32_V8    = 1

cpu_subtypes_arm64_32 = @dict[CPU_SUBTYPE_ARM64_32_ALL, CPU_SUBTYPE_ARM64_32_V8]

# DYLD Rebase / Bind / Export

# The following are used to encode dyld rebasing information
const REBASE_TYPE_POINTER           = 1
const REBASE_TYPE_TEXT_ABSOLUTE32   = 2
const REBASE_TYPE_TEXT_PCREL32      = 3
rebase_types = @dict[REBASE_TYPE_POINTER, REBASE_TYPE_TEXT_ABSOLUTE32, REBASE_TYPE_TEXT_PCREL32]

const REBASE_OPCODE_MASK                                = 0xF0
const REBASE_IMMEDIATE_MASK                             = 0x0F

const REBASE_OPCODE_DONE                                = 0x00
const REBASE_OPCODE_SET_TYPE_IMM                        = 0x10
const REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB         = 0x20
const REBASE_OPCODE_ADD_ADDR_ULEB                       = 0x30
const REBASE_OPCODE_ADD_ADDR_IMM_SCALED                 = 0x40
const REBASE_OPCODE_DO_REBASE_IMM_TIMES                 = 0x50
const REBASE_OPCODE_DO_REBASE_ULEB_TIMES                = 0x60
const REBASE_OPCODE_DO_REBASE_ADD_ADDR_ULEB             = 0x70
const REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB  = 0x80
rebase_opcodes = @dict[REBASE_OPCODE_DONE, REBASE_OPCODE_SET_TYPE_IMM, REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB, REBASE_OPCODE_ADD_ADDR_ULEB, 
  REBASE_OPCODE_ADD_ADDR_IMM_SCALED, REBASE_OPCODE_DO_REBASE_IMM_TIMES, REBASE_OPCODE_DO_REBASE_ULEB_TIMES, REBASE_OPCODE_DO_REBASE_ADD_ADDR_ULEB, REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB]

# The following are used to encode binding information
const BIND_TYPE_POINTER                 = 1
const BIND_TYPE_TEXT_ABSOLUTE32         = 2
const BIND_TYPE_TEXT_PCREL32            = 3

const BIND_SPECIAL_DYLIB_SELF             = 0
const BIND_SPECIAL_DYLIB_MAIN_EXECUTABLE  = -1
const BIND_SPECIAL_DYLIB_FLAT_LOOKUP      = -2

const BIND_SYMBOL_FLAGS_WEAK_IMPORT           = 0x1
const BIND_SYMBOL_FLAGS_NON_WEAK_DEFINITION   = 0x8

const BIND_OPCODE_MASK                              = 0xF0
const BIND_IMMEDIATE_MASK                           = 0x0F
const BIND_OPCODE_DONE                              = 0x00
const BIND_OPCODE_SET_DYLIB_ORDINAL_IMM             = 0x10
const BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB            = 0x20
const BIND_OPCODE_SET_DYLIB_SPECIAL_IMM             = 0x30
const BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM     = 0x40
const BIND_OPCODE_SET_TYPE_IMM                      = 0x50
const BIND_OPCODE_SET_ADDEND_SLEB                   = 0x60
const BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB       = 0x70
const BIND_OPCODE_ADD_ADDR_ULEB                     = 0x80
const BIND_OPCODE_DO_BIND                           = 0x90
const BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB             = 0xA0
const BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED       = 0xB0
const BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB  = 0xC0

# The following are used on the flags byte of a terminal node in the export information
const EXPORT_SYMBOL_FLAGS_KIND_MASK           = 0x03
const EXPORT_SYMBOL_FLAGS_KIND_REGULAR        = 0x00
const EXPORT_SYMBOL_FLAGS_KIND_THREAD_LOCAL   = 0x01
const EXPORT_SYMBOL_FLAGS_WEAK_DEFINITION     = 0x04
const EXPORT_SYMBOL_FLAGS_REEXPORT            = 0x08
const EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER   = 0x10
