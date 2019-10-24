
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
  get(cpu_types, header.cputype, "unknown")
end

# Returns pretty string description of CPU architecture, from a value
function pretty_header_cpu_type_desc(val::UInt32)
  get(pretty_cpu_types, val, "unknown")
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

# Returns a string description of a load command or, '???' with the hex value.
function load_cmd_desc(lc::LoadCommand)
  get(load_commands, lc.cmd, @sprintf("??? 0x%0x", lc.cmd))
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
function read_cstring(startIndex::Union{UInt32, Int64}, f::IOStream)
  existing_index = position(f)
  seek(f, startIndex)
  accum = UInt8[]
  while ((data = read(f, UInt8)) != 0x0)
    push!(accum, data)
  end
  seek(f, existing_index)
  return String(accum)
end

#====================================================================#
# Encodings
#====================================================================#

# https://en.wikipedia.org/wiki/LEB128
# MSB ------------------ LSB
#       10011000011101100101  In raw binary
#      010011000011101100101  Padded to a multiple of 7 bits
#  0100110  0001110  1100101  Split into 7-bit groups
# 00100110 10001110 11100101  Add high 1 bits on all but last (most significant) group to form bytes
#     0x26     0x8E     0xE5  In hexadecimal
# → 0xE5 0x8E 0x26            Output stream (LSB to MSB)
function uleb128encode(value::UInt64; padTo=0)
  val = value
  result = UInt8[]
  while val != 0
    byte = UInt8(val & 0x7f)
    val >>= 7
    if val != 0 || padTo != 0
      byte |= 0x80 # mark this byte that more bytes will follow.
    end
    push!(result, byte)
  end
  result
end

# https://en.wikipedia.org/wiki/LEB128
# MSB ------------------ LSB
#       01100111100010011011  In raw two's complement binary
#      101100111100010011011  Sign extended to a multiple of 7 bits
#  1011001  1110001  0011011  Split into 7-bit groups
# 01011001 11110001 10011011  Add high 1 bits on all but last (most significant) group to form bytes
#     0x59     0xF1     0x9B  In hexadecimal
# → 0x9B 0xF1 0x59            Output stream (LSB to MSB)
function sleb128encode(value::Int64, padTo=0)
  val = value
  result = UInt8[]
  count = 0
  more = true
  while more
    byte = UInt8(val & 0x7f)
    val >>= 7
    more = !((((val == 0 ) && ((byte & 0x40) == 0)) || ((val == -1) && ((byte & 0x40) != 0))))
    count += 1
    if more || count < padTo
      byte |= 0x80 # mark this byte that more bytes will follow
    end
    push!(result, byte)
  end
  # Pad out the rest of the bytes if we have to
  if count < padTo
    padValue = UInt8(val < 0 ? 0x7f : 0x00)
    while count >= padTo - 1
      push!(result, (padValue | 0x80))
      count += 1
    end
    #TODO: May need to emit a null byte as a terminator
  end
  result
end


function decodeULEB128(input::Array{UInt8,1}, dtype::DataType=UInt64, outsize::Integer=0)
  if outsize == 0
    outsize = length(input)
  end
  output = Array{dtype}(undef, outsize)
  j,k = 1,1
  while k <= length(output)
    output[k], shift = 0, 0
    while true
        byte = input[j]
        j += 1
        output[k] |= (dtype(byte & 0x7F) << shift)
        if (byte & 0x80 == 0) 
          break
        end
        shift += 7
    end
    k += 1
    if j > length(input) break end
  end
  output[1:k-1]
end

function decodeULEB128(f::IOStream)
  result = 0
  shift = 0
  while true
    byte = read(f, UInt8)
    result |= (UInt64(byte & 0x7F) << shift)
    if (byte & 0x80 == 0)
      break
    end
    shift += 7
  end
  result
end

function decodeSLEB128(input::Array{UInt8, 1})
  value, shift = 0, 0
  byte::UInt8 = 0xFF
  i = 1
  while byte >= 128
    byte = input[i]
    value |= Int64(byte & 0x7f) << shift
    shift += 7
    i += 1
  end
  # sign extend negative numbers
  if byte & 0x40 != 0
    value |= (-1) << shift
  end
  value
end

function decodeSLEB128(f::IOStream)
  value, shift = 0, 0
  byte::UInt8 = 0xFF
  i = 1
  while byte >= 128
    byte = read(f, UInt8)
    value |= Int64(byte & 0x7f) << shift
    shift += 7
    i += 1
  end
  # sign extend negative numbers
  if byte & 0x40 != 0
    value |= (-1) << shift
  end
  value
end

