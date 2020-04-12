
module JMO

include("constants.jl")
include("types.jl")
include("utils.jl")
include("read.jl")
include("iterators.jl")
include("disassemble.jl")
include("dyld_info.jl")
include("printing.jl")

using ArgParse
using Markdown

const VERSION = "0.0.3"

# Tests that a file has the correct magic value, or detects if the file is a fat file.
# Since we don't yet support fat files, print the summary and exit.
function check_file_is_valid(filename)
  f = open(filename)
  offset = 0
  magic = read_magic(f)
  # Check non machO file
  if in(magic, [MH_MAGIC, MH_MAGIC_64, MH_CIGAM, MH_CIGAM_64, FAT_MAGIC, FAT_CIGAM]) == false 
    println("This is not a valid machO file! Aborting!")
    exit(2)
  end
  close(f)
end

# This method either returns an offset to apply to the file for loading the thin header, 
# or exits the program.
function handle_fat_file(filename, args::Dict{String, Any})
  f = open(filename)
  offset = 0
  magic = read_magic(f)
  
  # Handle fat files and exit
  if is_magic_fat(magic)
    fat_headers = read_fat_header(f, 0, magic)
    archs =  map(h -> pretty_header_cpu_type_desc(h.cputype), filter(h-> typeof(h) == FatArch, fat_headers))
    arch_arg = get(args, "arch", Nothing)
    archs_arg = get(args, "archs", Nothing)

    # Have -archs option, print the archs and exit
    if archs_arg == true
      println(archs)
      exit(0)
    end

    # No -arch option
    if arch_arg == nothing
      println("To use jmo with fat files, please use the -arch option and choose from the following:")
      println(archs)
      exit(1)
    end
    
    cpu_type_from_arch = filter(f -> f.second == arch_arg, pretty_cpu_types) |> keys |> first
    if isempty(cpu_type_from_arch)
      println("Could not find matching architecture, please choose from the following:")
      println(archs)
      exit(1)
    end
    
    fat_arch_header = filter(h -> typeof(h) == FatArch && h.cputype == cpu_type_from_arch, fat_headers)
    magic_offset_for_arch = first(fat_arch_header).offset
    return magic_offset_for_arch
  end
  return 0
end

# -h option, print out the file header
function opt_read_header(filename, arch_offset)
  f, offset, is_64, is_swap, header_pair = read_header(filename, arch_offset)
  pprint(header_pair.first)
end

# --ls option, print out the names of all Load Cmds.
function opt_load_cmd_ls(filename, arch_offset)
  f, offset, is_64, is_swap, header_pair = read_header(filename, arch_offset)
  header = header_pair.first
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
function opt_shared_libs(filename, arch_offset)
  f, offset, is_64, is_swap, header_pair = read_header(filename, arch_offset)
  header = header_pair.first
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

function opt_objc_classnames(filename, arch_offset)
  f, offset, is_64, is_swap, header_meta = read_header(filename, arch_offset)
  for segment_pair in SegmentIterator(header_meta, is_64, is_swap)
    segment = segment_pair.first
    segname_string = String(segment.segname)
    for section_pair in SectionIterator(segment_pair, is_64, is_swap)
      section = section_pair.first 
      section_string = String(section.sectname)
      if occursin("__objc_classname", section_string)
        map(x->println(x), strings_from_section(section, section_pair.second.f))
        exit(0)
      end
    end
  end
end

function opt_disassemble(filename, arch_offset)
  f, offset, is_64, is_swap, header_meta = read_header(filename, arch_offset)
  for segment_pair in SegmentIterator(header_meta, is_64, is_swap)
    segment = segment_pair.first
    for section_pair in SectionIterator(segment_pair, is_64, is_swap)
      section = section_pair.first
      if occursin("__TEXT", String(section.segname)) && occursin("__text", String(section.sectname))
        dissassemble(section.offset, section.size, section.addr, f)
        exit(0)
      end
    end
  end
end

function opt_uuid(filename, arch_offset)
  f, offset, is_64, is_swap, header_meta = read_header(filename, arch_offset)
  header = header_meta.first
  offset += sizeof(header)
  for i = 1:header.ncmds
    load_cmd = read_generic(LoadCommand, f, offset, is_swap).first
    if load_cmd.cmd == LC_UUID
      uuid = read_generic(UUIDCommand, f, offset, is_swap)
      println(uuid)
      exit(0)
    end
    offset += load_cmd.cmdsize
  end
end

function opt_min_sdk(filename, arch_offset)
  f, offset, is_64, is_swap, header_meta = read_header(filename, arch_offset)
  header = header_meta.first
  offset += sizeof(header)
  for i = 1:header.ncmds
    load_cmd = read_generic(LoadCommand, f, offset, is_swap).first
    if in(load_cmd.cmd, [LC_VERSION_MIN_MACOSX, LC_VERSION_MIN_IPHONEOS, LC_VERSION_MIN_WATCHOS, LC_VERSION_MIN_TVOS])
      read_generic(VersionMinCommand, f, offset, is_swap) |> println
    end
    offset += load_cmd.cmdsize
  end
end

function opt_binding_opcodes(filename, arch_offset)
  f, offset, is_64, is_swap, header_meta = read_header(filename, arch_offset)
  header = header_meta.first
  offset += sizeof(header)
  orig_offset = offset
  offset = orig_offset
  
  # Get shared libs
  dylibs = Pair{DylibCommand, MetaStruct}[]
  for i = 1:header.ncmds
    load_cmd = read_generic(LoadCommand, f, offset, is_swap).first
    if load_cmd.cmd == LC_LOAD_DYLIB
      dylib = read_generic(DylibCommand, f, offset, is_swap)
      push!(dylibs, dylib)
    end
    offset += load_cmd.cmdsize
  end

  # Get segments
  offset = orig_offset
  segments = SegmentCommand64[]
  for segment_pair in SegmentIterator(header_meta, is_64, is_swap)
    segment = segment_pair.first
    push!(segments, segment)
  end

  # Read binding opcodes
  offset = orig_offset
  binding_info = Nothing
  lazy_binding_info = Nothing
  for i = 1:header.ncmds
    load_cmd = read_generic(LoadCommand, f, offset, is_swap).first
    if in(load_cmd.cmd, [LC_DYLD_INFO, LC_DYLD_INFO_ONLY])
      d = read_generic(DyldInfoCommand, f, offset, is_swap).first
      @printf("Binding info 0x%08x - 0x%08x\n", d.bind_off, d.bind_off + d.bind_size)
      binding_info = read_bind_opcodes(f, d.bind_off, d.bind_size, is_64, print_op_codes = true)
      println()
      #TODO: Add weak binding opcodes here as well
      @printf("Lazy binding info 0x%08x - 0x%08x\n", d.lazy_bind_off, d.lazy_bind_off + d.lazy_bind_size)
      lazy_binding_info = read_bind_opcodes(f, d.lazy_bind_off, d.lazy_bind_size, is_64, print_op_codes = true)
      println()
    end
    offset += load_cmd.cmdsize
  end
  
  # Pretty print records
  "Binding Records" |> println
  if binding_info != Nothing
    pprint(dylibs, segments, binding_info)
  else
    println("No binding info")
  end
  "Lazy Binding Records" |> println
  if lazy_binding_info != Nothing
    pprint(dylibs, segments, lazy_binding_info, is_lazy = true)
  else
    println("No lazy binding info")
  end
end

function parse_cli_opts(args) 
  s = ArgParseSettings(description = "MachO object file viewer", version = VERSION, add_version = true, add_help = false)

  @add_arg_table! s begin
      "--header", "-h"
        action = :store_true
        help = "display header"
      "--arch", "-a"
        action = :store_arg
        arg_type = String
        help = "select an architecture for fat files"
      "--archs"
        action = :store_true
        help = "print architectures"
      "--ls", "-c"
        help = "show load commands summary"
        action = :store_true
      "--shared-libs", "-L"
        help = "show names and version numbers of the shared libraries that the object file uses."
        action = :store_true
      "--objc-classes"
        help = "lists names of objective-c classes that exist in the object file"
        action = :store_true
      "--disassemble"
        help = "Disassemble the __TEXT section"
        action = :store_true
      "--min-sdk"
        help = "Show the deployment target the binary was compiled for"
        action = :store_true
      "--uuid"
        help = "Print the 128-bit UUID for an image or its corresponding dSYM file."
        action = :store_true
      "--binding-opcodes"
        help = "Shows binding info op codes"
        action = :store_true
      "--help"
        help = "Show help"
        action = :show_help
      "file"                 # a positional argument
        required = true
        help = "File to read"
  end
  arg_dict = parse_args(s) # the result is a Dict{String,Any}
  filename = arg_dict["file"]

  # Check that this is a file we can read
  check_file_is_valid(filename)

  # Check if we need to offset to a different slice.
  arch_offset = handle_fat_file(filename, arg_dict)

  # Handle args
  if arg_dict["header"] == true 
    opt_read_header(filename, arch_offset)
  elseif arg_dict["ls"] == true
    opt_load_cmd_ls(filename, arch_offset)
  elseif arg_dict["shared-libs"] == true
    opt_shared_libs(filename, arch_offset)
  elseif arg_dict["objc-classes"] == true
    opt_objc_classnames(filename, arch_offset)
  elseif arg_dict["disassemble"] == true
    opt_disassemble(filename, arch_offset)
  elseif arg_dict["uuid"] == true
    opt_uuid(filename, arch_offset)
  elseif arg_dict["min-sdk"] == true
    opt_min_sdk(filename, arch_offset)
  elseif arg_dict["binding-opcodes"] == true
    opt_binding_opcodes(filename, arch_offset)
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
