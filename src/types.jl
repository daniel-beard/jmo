
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
end