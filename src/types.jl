
using StaticArrays

# Contains meta information about each struct we parse:
struct MetaStruct
  offset::Int64
  f::IOStream
end

struct MachHeader
  magic::UInt32
  cputype::UInt32
  cpusubtype::UInt32
  filetype::UInt32
  ncmds::UInt32
  sizeofcmds::UInt32
  flags::UInt32
end

struct MachHeader64
  magic::UInt32
  cputype::UInt32
  cpusubtype::UInt32
  filetype::UInt32
  ncmds::UInt32
  sizeofcmds::UInt32
  flags::UInt32
  reserved::UInt32
end

struct LoadCommand
  cmd::UInt32
  cmdsize::UInt32
end

struct UUIDCommand
  cmd::UInt32
  cmdsize::UInt32
  uuid::SVector{16, UInt8}
end

const VM_Prot_t = Base.Cint
struct SegmentCommand
  cmd::UInt32
  cmdsize::UInt32
  segname::SVector{16, UInt8}
  vmaddr::UInt32
  vmsize::UInt32
  fileoff::UInt32
  filesize::UInt32
  maxprot::VM_Prot_t
  initprot::VM_Prot_t
  nsects::UInt32
  flags::UInt32
end


struct SegmentCommand64
  cmd::UInt32
  cmdsize::UInt32
  segname::SVector{16, UInt8}
  vmaddr::UInt64
  vmsize::UInt64
  fileoff::UInt64
  filesize::UInt64
  maxprot::VM_Prot_t
  initprot::VM_Prot_t
  nsects::UInt32
  flags::UInt32
end

struct Section
  sectname::SVector{16, UInt8}
  segname::SVector{16, UInt8}
  addr::UInt32
  size::UInt32
  offset::UInt32
  align::UInt32
  reloff::UInt32
  nreloc::UInt32
  flags::UInt32
  reserved1::UInt32
  reserved2::UInt32
end

struct Section64
  sectname::SVector{16, UInt8}
  segname::SVector{16, UInt8}
  addr::UInt64
  size::UInt64
  offset::UInt32
  align::UInt32
  reloff::UInt32
  nreloc::UInt32
  flags::UInt32
  reserved1::UInt32
  reserved2::UInt32
  reserved3::UInt32
end

# Variable length string union, we only need the offset, the pointer is not used in MachO files
# A variable length string in a load command is represented by an lc_str
# union.  The strings are stored just after the load command structure and
# the offset is from the start of the load command structure.  The size
# of the string is reflected in the cmdsize field of the load command.
# Once again any padded bytes to bring the cmdsize field to a multiple
# of 4 bytes must be zero.
const LCStr = UInt32

# This structure is flattened from the load cmd & Dylib structure.
struct DylibCommand
  cmd::UInt32
  cmdsize::UInt32
  name::LCStr
  timestamp::UInt32
  current_version::UInt32
  compatibility_version::UInt32
end

struct RPathCommand
  cmd::UInt32
  cmdsize::UInt32
  path::LCStr
end

# Contains the min OS version on which this binary was built to run
struct VersionMinCommand
  cmd::UInt32     # LC_VERSION_MIN_MACOSX || LC_VERSION_MIN_IPHONEOS || LC_VERSION_MIN_WATCHOS || LC_VERSION_MIN_TVOS
  cmdsize::UInt32
  version::UInt32 # X.Y.Z is encoded in nibbles xxxx.yy.zz
  sdk::UInt32     # X.Y.Z is encoded in nibbles xxxx.yy.zz
end

# min OS version for which this binary was built to run, for its platform.
# The list of known platforms and tool values following it.
struct BuildVersionCommand
  cmd::UInt32       # LC_BUILD_VERSION
  cmdsize::UInt32   # sizeof(BuildVersionCommand) + (ntools * sizeof(BuildToolVersion))
  platform::UInt32  # platform
  minos::UInt32     # X.Y.Z is encoded in nibbles xxxx.yy.zz
  sdk::UInt32       # X.Y.Z is encoded in nibbles xxxx.yy.zz
  ntools::UInt32    # number of tool entries following this
end

struct BuildToolVersion
  tool::UInt32    # enum for the tool
  version::UInt32 # version number of the tool
end

# Specifies the symbol table for this file. This information is used by both static and dynamic linkers when linking the file, 
# and also by debuggers to map symbols to the original source code files from which the symbols were generated.
struct SymtabCommand
  cmd::UInt32       # LC_SYMTAB
  cmdsize::UInt32   # sizeof(SymtabCommand)
  symoff::UInt32    # symbol table offset
  nsyms::UInt32     # number of symbol table entries
  stroff::UInt32    # string table offset
  strsize::UInt32   # string table size in bytes
end



