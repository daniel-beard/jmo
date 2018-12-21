
include("types.jl")
include("constants.jl")

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