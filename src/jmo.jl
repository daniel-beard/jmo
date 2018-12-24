
module JMO 

include("constants.jl")
include("types.jl")
include("utils.jl")

using ArgParse

function printHeader64(header)
  h = header
  println("magic\t\tcputype\t\tcpusubtype\tfiletype\tncmds\t\tsizeofcmds\tflags\t\treserved")
  println("$(repr(h.magic))\t$(h.cputype)\t$(h.cpusubtype)\t$(h.filetype)\t\t$(h.ncmds)\t\t$(h.sizeofcmds)\t\t$(h.flags)\t\t$(h.reserved)")
end

function read_magic(f::IOStream)
  seekstart(f)
  read(f, UInt32)
end

function is_magic_64(magic::UInt32)
  magic == MH_MAGIC_64 || magic == MH_CIGAM_64
end

function should_swap_bytes(magic::UInt32)
  magic == MH_CIGAM || magic == MH_CIGAM_64
end

function read_mach_header(f::IOStream, offset, is_64::Bool, is_swap::Bool)
  seek(f, offset)
  if is_64 
    T = MachHeader64
    header_64 = T(
      read(f, fieldtype(T, 1)), # header is always native endianness.
      is_swap ? bswap(read(f, fieldtype(T, 2))) : read(f, fieldtype(T, 2)),
      is_swap ? bswap(read(f, fieldtype(T, 3))) : read(f, fieldtype(T, 3)),
      is_swap ? bswap(read(f, fieldtype(T, 4))) : read(f, fieldtype(T, 4)),
      is_swap ? bswap(read(f, fieldtype(T, 5))) : read(f, fieldtype(T, 5)),
      is_swap ? bswap(read(f, fieldtype(T, 6))) : read(f, fieldtype(T, 6)),
      is_swap ? bswap(read(f, fieldtype(T, 7))) : read(f, fieldtype(T, 7)),
      is_swap ? bswap(read(f, fieldtype(T, 8))) : read(f, fieldtype(T, 8)),
    )
    return header_64
  else 
    T = MachHeader
    header = T(
      read(f, fieldtype(T, 1)), # header is always native endianness.
      is_swap ? bswap(read(f, fieldtype(T, 2))) : read(f, fieldtype(T, 2)),
      is_swap ? bswap(read(f, fieldtype(T, 3))) : read(f, fieldtype(T, 3)),
      is_swap ? bswap(read(f, fieldtype(T, 4))) : read(f, fieldtype(T, 4)),
      is_swap ? bswap(read(f, fieldtype(T, 5))) : read(f, fieldtype(T, 5)),
      is_swap ? bswap(read(f, fieldtype(T, 6))) : read(f, fieldtype(T, 6)),
      is_swap ? bswap(read(f, fieldtype(T, 7))) : read(f, fieldtype(T, 7)),
    )
    return header
  end
end

function read_generic(T, f::IOStream, offset::Int64, is_swap::Bool)
  seek(f, offset)
  nfields = fieldcount(T)
  fields = Any[]
  for i = 1:nfields
    field = is_swap ? bswap(read(f, fieldtype(T, i))) : read(f, fieldtype(T, i))
    push!(fields, field)
  end
  return T(fields...)
end

# iostream, offset, header type, ncmds, is_swap
# Don't need is_64, can interpret from LC_COMMAND / LC_COMMAND_64
# Reads all segment commands
function read_segment_commands(f::IOStream, load_commands_offset::Int64, ncmds::UInt32, is_swap::Bool)
  actual_offset = load_commands_offset
  for i = 1:ncmds
    # load_cmd = read_load_command(f, actual_offset, is_swap)
    load_cmd = read_generic(LoadCommand, f, actual_offset, is_swap)
    
    # Load SegmentCommand && SegmentCommand64 values
    # Since only the types of fields change, the fieldtype's handle that.
    if load_cmd.cmd == LC_SEGMENT_64
      segment_command = read_generic(SegmentCommand64, f, actual_offset, is_swap)
      segname_string = String(segment_command.segname)
      println("Segname: $(segname_string)")
      println("Segsize: $(sizeof(segment_command))")
      println("nsect: $(segment_command.nsects)")
      
      # Read sections for this segment
      current_section_offset = actual_offset + sizeof(segment_command)
      for sect = 1:segment_command.nsects
        section = read_generic(Section64, f, current_section_offset, is_swap)
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

      
      # Load section commands here...
      
    elseif load_cmd.cmd == LC_SEGMENT
      segment_command = read_generic(SegmentCommand, f, actual_offset, is_swap)
      segname_string = String(segment_command.segname)
      println("Segname: $(segname_string)")
      println("Segsize: $(sizeof(segment_command))")
      
      # Load section commands here...
      
    elseif load_cmd.cmd == LC_UUID
      uuid = read_generic(UUIDCommand, f, actual_offset, is_swap)
      uuid_string = string(uuid.uuid)
      println("Loaded UUID: $(uuid_desc(uuid))")
    end
    actual_offset += load_cmd.cmdsize
  end
end

function openFile(filename)
  f = open(filename)
  
  offset = 0
  magic = read_magic(f)  
  is_64 = is_magic_64(magic)
  is_swap = should_swap_bytes(magic)
  
  println("Is magic 64 $is_64")
  println("Should swap bytes $is_swap")
  
  # read the header
  header = read_mach_header(f, offset, is_64, is_swap)
  offset += sizeof(header)
  println(header)
  printHeader64(header)
  println(header_filetype_desc(header))
  println(header_flags_desc(header))
  
  # read segment commands
  load_cmds = read_segment_commands(f, offset, header.ncmds, is_swap)
  # println(load_cmds)
  
  close(f)
end

function parse_cli_opts(args) 
  s = ArgParseSettings(description = "MachO object file viewer")

  @add_arg_table s begin
      "-l"
        action = :store_true
        help = "Display header"
      "--opt2", "-o"         # another option, with short form
      "file"                 # a positional argument
  end

  parsed_args = parse_args(s) # the result is a Dict{String,Any}
  println("Parsed args:")
  for (key,val) in parsed_args
      println("  $key  =>  $(repr(val))")
  end
end

parse_cli_opts(ARGS)
openFile("/Users/dbeard/Dev/Personal/jmo/Binaries/ObjcThin")

end # module