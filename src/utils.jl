
include("types.jl")
include("constants.jl")

using Printf

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

# Type show implementations
####################################

function Base.show(io::IO, h::Union{MachHeader, MachHeader64})
  print(io, "magic\t\tcputype\t\tcpusubtype\tfiletype\tncmds\t\tsizeofcmds\tflags\t\treserved\n")
  print(io, "$(repr(h.magic))\t$(h.cputype)\t$(h.cpusubtype)\t$(h.filetype)\t\t$(h.ncmds)\t\t$(h.sizeofcmds)\t\t$(h.flags)\t\t$(h.reserved)\n")
end

function Base.show(io::IO, uuid::UUIDCommand)
  uuid_val = uuid.uuid
  string = @sprintf("%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X", uuid_val...)
  println(io, "LC_UUID:")
  println(io, string)
end

function Base.show(io::IO, version::VersionMinCommand)
  map = Dict(
    LC_VERSION_MIN_MACOSX=>"LC_VERSION_MIN_MACOSX",
    LC_VERSION_MIN_IPHONEOS=>"LC_VERSION_MIN_IPHONEOS",
    LC_VERSION_MIN_WATCHOS=>"LC_VERSION_MIN_WATCHOS",
    LC_VERSION_MIN_TVOS=>"LC_VERSION_MIN_TVOS"
  )
  name = get(map, version.cmd, "UNKNOWN")
  println(io, "$(name):")
  println(io, "Version: $(version_desc(version.version))")
  println(io, "SDK: $(version_desc(version.sdk))")
end

# function Base.show(io::IO, dylib::DylibCommand)
  # TODO: I think here we might need to parse all structs into a meta-structure, 
  # one that contains base offsets in the file, since things like the LCStr in DylibCommand depend on the 
  # load commands offset, since the offset is relative, not absolute.
# end