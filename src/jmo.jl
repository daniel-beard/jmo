
module JMO 

include("constants.jl")
include("types.jl")
include("utils.jl")

using ArgParse

const COMMAND_MAP = Dict(
  LC_UUID => UUIDCommand,
  LC_SEGMENT => SegmentCommand,
  LC_SEGMENT_64 => SegmentCommand64,
  LC_LOAD_DYLIB => DylibCommand,
  LC_VERSION_MIN_IPHONEOS => VersionMinCommand,
  LC_VERSION_MIN_MACOSX => VersionMinCommand,
  LC_VERSION_MIN_TVOS => VersionMinCommand,
  LC_VERSION_MIN_WATCHOS => VersionMinCommand,
)

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
      if haskey(COMMAND_MAP, load_cmd.cmd)
        load_type = COMMAND_MAP[load_cmd.cmd]
        command = read_generic(load_type, f, actual_offset, is_swap)
        println(command)
      end
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

using Markdown
# function myshow(io::IO, mime, f::Union{MachHeader, MachHeader64})
#   t = Markdown.Table([[string(f.flags)]], [:c])
#   m = Markdown.MD(t)
#   show(io, mime, m)
# end

function openFile(filename)
  f = open(filename)
  
  offset = 0
  magic = read_magic(f)  
  is_64 = is_magic_64(magic)
  is_swap = should_swap_bytes(magic)
  
  # read the header
  header_type = is_64 ? MachHeader64 : MachHeader
  header = read_generic(header_type, f, offset, is_swap, first_field_flip = false).first
  offset += sizeof(header)
  println(header)
  println(header_filetype_desc(header))
  println(header_flags_desc(header))
  println(header_cpu_type_desc(header))
  #TODO: Implement header_cpu_subtype_desc
  
  #TODO: Turn this into a function that takes a struct and outputs a table.
  a = Markdown.MD(Markdown.Table(Any[Any["a", "b"], Any["1", "2"]], [:l, :r]))
  print(Markdown.plain(a))
  print(Markdown.rst(a)) # <----- this one has a better table-like look.
  
  
  # read segment commands
  load_cmds = read_segment_commands(f, offset, header.ncmds, is_swap)
  
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

# Equivalent to main func
Base.@ccallable function julia_main(ARGS::Vector{String})::Cint
  parse_cli_opts(ARGS)
  openFile("/Users/dbeard/Dev/Personal/jmo/Binaries/ObjcThin")
  return 0
end

julia_main([""])

end # module