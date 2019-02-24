
module JMO 

include("constants.jl")
include("types.jl")
include("utils.jl")

using ArgParse
using Markdown

const VERSION = "0.0.1"

function read_magic(f::IOStream)
  seekstart(f)
  read(f, UInt32)
end

function is_magic_fat(magic::UInt32)
  magic == FAT_MAGIC || magic == FAT_CIGAM
end

function is_magic_64(magic::UInt32)
  magic == MH_MAGIC_64 || magic == MH_CIGAM_64
end

function should_swap_bytes(magic::UInt32)
  magic == MH_CIGAM || magic == MH_CIGAM_64
end

# Generic read function, returns a Pair containing the type T and a meta struct that contains some 
# meta info like offset and IOStream
function read_generic(T, f::IOStream, offset::Int64, is_swap::Bool; first_field_flip = true)::Pair{T, MetaStruct}
  seek(f, offset)
  nfields = fieldcount(T)
  fields = Any[]
  for i = 1:nfields
    if i == 1 && !first_field_flip
      field = read(f, fieldtype(T, i))
    else
      field = is_swap ? bswap(read(f, fieldtype(T, i))) : read(f, fieldtype(T, i))
    end
    push!(fields, field)
  end
  meta = MetaStruct(offset, f)
  return Pair(T(fields...), meta)
end

# Read a fat header
# Returns a list containing the fat header, then the fat arch types.
function read_fat_header(f::IOStream, offset::Int64, magic::UInt32)
  # Fat files are always treated as BigEndian
  current_arch_little_endian = Base.ENDIAN_BOM == 0x04030201
  is_swap = current_arch_little_endian
  result = Any[]
  seek(f, offset)
  T = FatHeader
  nfields = fieldcount(T)
  fields = Any[]
  for i = 1:nfields
    field = is_swap ? bswap(read(f, fieldtype(T, i))) : read(f, fieldtype(T, i))
    push!(fields, field)
  end
  fat_header = T(fields...)
  push!(result, fat_header)
  for n in 1:fat_header.nfat_arch
    T = FatArch
    nfields = fieldcount(T)
    fields = Any[]
    for i = 1:nfields
      field = is_swap ? bswap(read(f, fieldtype(T, i))) : read(f, fieldtype(T, i))
      push!(fields, field)
    end
    push!(result, T(fields...))
  end
  result
end

# Tests that a file has the correct magic value, or detects if the file is a fat file.
# Since we don't yet support fat files, print the summary and exit.
function check_file_is_valid(filename)
  f = open(filename)
  offset = 0
  magic = read_magic(f)
  # Handle fat files and exit
  if is_magic_fat(magic)
    fat_headers = read_fat_header(f, 0, magic)
    map(x->pprint(x), fat_headers)
    println("jmo doesn't currently support FAT files, to use with this utility, extract a slice using `lipo`")
    exit(1)
  end
  # Check non machO file
  if in(magic, [MH_MAGIC, MH_MAGIC_64, MH_CIGAM, MH_CIGAM_64]) == false 
    println("This is not a valid machO file! Aborting!")
    exit(2)
  end
  close(f)
end

# -h option, print out the file header
function opt_read_header(filename)
  f, offset, is_64, is_swap, header = read_header(filename)
  pprint(header)
end

# --ls option, print out the names of all Load Cmds.
function opt_load_cmd_ls(filename)
  f, offset, is_64, is_swap, header = read_header(filename)
  offset += sizeof(header)
  commands = LoadCommand[]
  for i = 1:header.ncmds
    load_cmd = read_generic(LoadCommand, f, offset, is_swap).first
    push!(commands, load_cmd)
    offset += load_cmd.cmdsize
  end
  println("Load Commands:")
  map(lc->load_cmd_desc(lc) |> println, commands)
end

# -L option, print out the dylibs that this object file uses
function opt_shared_libs(filename)
  f, offset, is_64, is_swap, header = read_header(filename)
  offset += sizeof(header)
  for i = 1:header.ncmds
    load_cmd = read_generic(LoadCommand, f, offset, is_swap).first
    if load_cmd.cmd == LC_LOAD_DYLIB
      dylib = read_generic(DylibCommand, f, offset, is_swap)
      println(dylib)
    end
    offset += load_cmd.cmdsize
  end
end

# iostream, offset, header type, ncmds, is_swap
# Don't need is_64, can interpret from LC_COMMAND / LC_COMMAND_64
# Reads all segment commands
function read_segment_commands(f::IOStream, load_commands_offset::Int64, ncmds::UInt32, is_swap::Bool)
  actual_offset = load_commands_offset
  for i = 1:ncmds
    load_cmd = read_generic(LoadCommand, f, actual_offset, is_swap).first
    
    # Load SegmentCommand && SegmentCommand64 values
    # Since only the types of fields change, the fieldtype's handle that.
    if load_cmd.cmd == LC_SEGMENT_64
      segment_command = read_generic(SegmentCommand64, f, actual_offset, is_swap).first
      segname_string = String(segment_command.segname)
      println("Segname: $(segname_string)")
      println("Segsize: $(sizeof(segment_command))")
      println("nsect: $(segment_command.nsects)")
      
      # Read sections for this segment
      current_section_offset = actual_offset + sizeof(segment_command)
      for sect = 1:segment_command.nsects
        section = read_generic(Section64, f, current_section_offset, is_swap).first
        println("Section: $(String(section.sectname)) $(String(section.segname))")
        println("Section type: $(section_type_desc(section))")
        println("Section attr: $(section_attributes_desc(section))")
        
        # Test printing out contents of __cstring
        # TODO: Need to read the flags of the sections and figure out if these are c-strings 
        # BEFORE trying to dump the constants.
        if occursin("__cstring", String(section.sectname))
          strings_from_section(section, f) |> println
          section_type_desc(section) |> println
        end
        
        if occursin("__objc_classname", String(section.sectname))
          strings_from_section(section, f) |> println
        end
        
        if occursin("__got", String(section.sectname))
          section_type_desc(section) |> println
          section_attributes_desc(section) |> println
        end
        
        current_section_offset += sizeof(section)
      end

      # Load using the lookup map
    else 
      # Do we have a match? 
      # if haskey(COMMAND_MAP, load_cmd.cmd)
      #   load_type = COMMAND_MAP[load_cmd.cmd]
      #   command = read_generic(load_type, f, actual_offset, is_swap)
      #   println(command)
      # end
    end
      
    # elseif load_cmd.cmd == LC_SEGMENT
    #   segment_command = read_generic(SegmentCommand, f, actual_offset, is_swap)
    #   segname_string = String(segment_command.segname)
    #   println("Segname: $(segname_string)")
    #   println("Segsize: $(sizeof(segment_command))")
      
      
    # elseif load_cmd.cmd == LC_UUID
    #   uuid = read_generic(UUIDCommand, f, actual_offset, is_swap)
    #   uuid_string = string(uuid.uuid)
    #   println("Loaded UUID: $(uuid_desc(uuid))")
    # elseif load_cmd.cmd == LC_LOAD_DYLIB
    #   dylib = read_generic(DylibCommand, f, actual_offset, is_swap)
    #   dylib_name = read_cstring(load_cmd_offset + dylib.name, f)
    #   println("Loaded DYLIB: $(dylib_name)")
      
    # elseif in(load_cmd.cmd, [LC_VERSION_MIN_MACOSX, LC_VERSION_MIN_IPHONEOS, LC_VERSION_MIN_WATCHOS, LC_VERSION_MIN_TVOS])
    #   version_min = read_generic(VersionMinCommand, f, actual_offset, is_swap)
    #   println("Loaded version min: $(version_min.version) $(version_min.sdk)")  
    #   version_desc(version_min.version) |> println
    # end
    actual_offset += load_cmd.cmdsize
  end
end

# Reads a header, returning an IOStream, offset, is_64, is_swap, and a header.
function read_header(filename)
  f = open(filename)
  offset = 0
  magic = read_magic(f)  
  is_64 = is_magic_64(magic)
  is_swap = should_swap_bytes(magic)
  header_type = is_64 ? MachHeader64 : MachHeader
  header = read_generic(header_type, f, offset, is_swap, first_field_flip = false).first
  return f, offset, is_64, is_swap, header
end

function parse_cli_opts(args) 
  s = ArgParseSettings(description = "MachO object file viewer", version = VERSION, add_version = true, add_help = false)

  @add_arg_table s begin
      "--header", "-h"
        action = :store_true
        help = "display header"
      "--ls", "-c"
        help = "show load commands summary"
        action = :store_true
      "--shared-libs", "-L"
        help = "show names and version numbers of the shared libraries that the object file uses."
        action = :store_true
      "--objc-classes"
        help = "lists names of objective-c classes that exist in the object file"
        action = :store_true
      "file"                 # a positional argument
        required = true
        help = "File to read"
  end
  arg_dict = parse_args(s) # the result is a Dict{String,Any}
  filename = arg_dict["file"]
  
  # TODO: Could in future have a 'read_headers' method here as part of setup
  # Then each opt_* method can map over the headers passed to it, or we could filter by an -arch option.
  
  # Check that this is a file we can read
  check_file_is_valid(filename)
  
  # Handle args
  if arg_dict["header"] == true 
    opt_read_header(filename)
  elseif arg_dict["ls"] == true
    opt_load_cmd_ls(filename)
  elseif arg_dict["shared-libs"] == true
    opt_shared_libs(filename)
  elseif arg_dict["objc-classes"] == true
    #TODO: Implement me
  end
end

# Equivalent to main func
Base.@ccallable function julia_main(ARGS::Vector{String})::Cint
  parse_cli_opts(ARGS)
  return 0
end
# Comment out when compiling to binary.
julia_main([""])

end # module