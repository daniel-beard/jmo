
using StaticArrays

struct MachHeader
  magic::UInt32
  cputype::UInt32 # integer
  cpusubtype::UInt32 # integer
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

# Contains the min OS version on which this binary was built to run
struct VersionMinCommand
  cmd::UInt32     # LC_VERSION_MIN_MACOSX || LC_VERSION_MIN_IPHONEOS || LC_VERSION_MIN_WATCHOS || LC_VERSION_MIN_TVOS
  cmdsize::UInt32
  version::UInt32 # X.Y.Z is encoded in nibbles xxxx.yy.zz
  sdk::UInt32     # X.Y.Z is encoded in nibbles xxxx.yy.zz
end