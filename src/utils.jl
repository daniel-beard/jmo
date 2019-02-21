
include("types.jl")
include("constants.jl")

using Printf
using Markdown

# This file contains helper functions for extracting data from sections / segments.

# Returns the contents of a section containing c-strings
# Does not modify IOStreams position
function strings_from_section(section::Union{Section, Section64}, f::IOStream)
  existing_index = position(f)
  seek(f, section.offset)
  data = read(f, section.size)
  accum = UInt8[]
  result = String[]
  for val in data
    if val == 0x00
      push!(result, String(accum))
      accum = UInt8[]
    else 
      push!(accum, val)
    end
  end
  seek(f, existing_index)
  return result
end

# Returns the string description of the header file type, e.g. "MH_EXECUTE"
function header_filetype_desc(header::Union{MachHeader, MachHeader64})
  header_filetypes[header.filetype]
end

# Returns the string description of the header flags, e.g. "MH_DYLDLINK|MH_NOUNDEFS|MH_PIE|MH_TWOLEVEL"
function header_flags_desc(header::Union{MachHeader, MachHeader64})
  set_bit_flags = filter(x -> (x & header.flags) != 0, keys(header_flags))
  descriptions = String[]
  for flag in set_bit_flags
    push!(descriptions, header_flags[flag])
  end
  join(sort(descriptions), '|')
end

# Returns a string description of the CPU architecture, from a mach header or fat arch header.
function header_cpu_type_desc(header::Union{MachHeader, MachHeader64, FatArch})
  cpu_types[header.cputype]
end

# Returns a string description of the CPU subtype, from a mach header
function header_cpu_subtype_desc(header::Union{MachHeader, MachHeader64})
  arch_to_subtype_map = Dict(
    CPU_TYPE_VAX => cpu_subtypes_vax,
    CPU_TYPE_MC680x0 => cpu_subtypes_mc680,
    CPU_TYPE_I386 => cpu_subtypes_i386,
    CPU_TYPE_X86_64 => cpu_subtypes_x86_64,
    CPU_TYPE_MC98000 => cpu_subtypes_mc98000,
    CPU_TYPE_HPPA => cpu_subtypes_hppa,
    CPU_TYPE_ARM => cpu_subtypes_arm,
    CPU_TYPE_ARM64 => cpu_subtypes_arm64,
    CPU_TYPE_ARM64_32 => cpu_subtypes_arm64_32, 
    CPU_TYPE_MC88000 => cpu_subtypes_mc88000,
    CPU_TYPE_SPARC => cpu_subtypes_sparc,
    CPU_TYPE_I860 => cpu_subtypes_i860,
    CPU_TYPE_POWERPC => cpu_subtypes_powerpc)
    #TODO: Add some handling for not found values, fallback to an "unknown" desc.
  subtype_map = arch_to_subtype_map[header.cputype] 
  subtype = subtype_map[header.cpusubtype & ~CPU_SUBTYPE_MASK]
  subtype
end

# Returns section type as string from section flags
# e.g. "S_REGULAR"
function section_type_desc(section::Union{Section, Section64})
  type_flag = section.flags & SECTION_TYPE
  section_types[type_flag]
end

# Returns section attributes as combined string
# e.g. "S_ATTR_DEBUG|S_ATTR_NO_DEAD_STRIP"
function section_attributes_desc(section::Union{Section, Section64})
  attributes_flag = section.flags & SECTION_ATTRIBUTES
  set_attributes_flags = filter(x -> (x & attributes_flag) != 0, keys(section_attributes))
  descriptions = String[]
  for flag in set_attributes_flags
    push!(descriptions, section_attributes[flag])
  end
  join(sort(descriptions), '|')
end

function version_desc(val::UInt32)
  # X.Y.Z is encoded in nibbles xxxx.yy.zz
  x = val >> 16
  y = (val & 0xffff) >> 8
  z = val & 0xff
  @sprintf("%d.%d.%d", x, y, z)
end

# Reads a \0 delimited cstring starting at an index.
# Does not modify IOStreams position
function read_cstring(startIndex::UInt32, f::IOStream)
  existing_index = position(f)
  seek(f, startIndex)
  accum = UInt8[]
  while ((data = read(f, UInt8)) != 0x0)
    push!(accum, data)
  end
  seek(f, existing_index)
  return String(accum)
end

# Outputs a markdown table
# Param is an array of alternating titles + values, e.g.
# ["title1", "val1", "title2", "val2"]
function printmdtable(titlesAndValues::Array{Any})
  titles = Any[]
  values = Any[]
  for (index, val) in pairs(titlesAndValues)
    if index % 2 != 0 
      push!(titles, val)
    else
      push!(values, val)
    end
  end
  table = Markdown.MD(Markdown.Table(Any[titles, values], repeat([:c], length(titles))))
  println(Markdown.rst(table))
end

# Pretty print implementations
####################################

function pprint(header::Union{MachHeader, MachHeader64})
  type = isa(header, MachHeader) ? "MachHeader" : "MachHeader64"
  println(type)
  t = Any[]
  push!(t, "magic", @sprintf("0x%0x", header.magic))
  push!(t, "cputype", header_cpu_type_desc(header))
  push!(t, "cpusubtype", header_cpu_subtype_desc(header))
  push!(t, "filetype", header_filetype_desc(header))
  push!(t, "ncmds", @sprintf("%d", header.ncmds))
  push!(t, "sizeofcmds", @sprintf("%d", header.sizeofcmds))
  push!(t, "flags", header_flags_desc(header))
  printmdtable(t)
end

function pprint(fatHeader::FatHeader)
  println("FatHeader")
  t = Any[]
  push!(t, "magic", @sprintf("0x%0x", fatHeader.magic))
  push!(t, "nfat_arch", @sprintf("%d", fatHeader.nfat_arch))
  printmdtable(t)
end

function pprint(fatArch::FatArch)
  println("FatArch")
  t = Any[]
  push!(t, "cputype", header_cpu_type_desc(fatArch))
  push!(t, "cpusubtype", @sprintf("0x%0x", fatArch.cpusubtype))
  push!(t, "offset", @sprintf("0x%0x", fatArch.offset))
  push!(t, "size", @sprintf("%d", fatArch.size))
  push!(t, "align", @sprintf("%d", fatArch.align))
  printmdtable(t)
end

# Base.show implementations
####################################

function Base.show(io::IO, h::Union{MachHeader, MachHeader64})
  print(io, "magic\t\tcputype\t\tcpusubtype\tfiletype\tncmds\t\tsizeofcmds\tflags\t\treserved\n")
  print(io, "$(repr(h.magic))\t$(h.cputype)\t$(h.cpusubtype)\t$(h.filetype)\t\t$(h.ncmds)\t\t$(h.sizeofcmds)\t\t$(h.flags)\t\t$(h.reserved)\n")
end

function Base.show(io::IO, uuid::Pair{UUIDCommand, MetaStruct})
  uuid = uuid.first
  uuid_val = uuid.uuid
  string = @sprintf("%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X", uuid_val...)
  println(io, "LC_UUID:")
  println(io, string)
end

function Base.show(io::IO, version::Pair{VersionMinCommand, MetaStruct})
  map = @dict[LC_VERSION_MIN_MACOSX,LC_VERSION_MIN_IPHONEOS,LC_VERSION_MIN_WATCHOS,LC_VERSION_MIN_TVOS]
  version = version.first
  name = get(map, version.cmd, "UNKNOWN")
  println(io, "$(name):")
  println(io, "Version: $(version_desc(version.version))")
  println(io, "SDK: $(version_desc(version.sdk))")
end

function Base.show(io::IO, dylib::Pair{DylibCommand, MetaStruct})
  (dylib, meta) = dylib
  offset = UInt32(meta.offset + dylib.name)
  name = read_cstring(offset, meta.f)
  println(io, "LC_LOAD_DYLIB:")
  println(io, name)
  # TODO: Print out the rest of the fields here. Should I introduce a verbose flag for fields I don't really care about?
end