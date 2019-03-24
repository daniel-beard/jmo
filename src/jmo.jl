
module JMO 

include("constants.jl")
include("types.jl")
include("utils.jl")
include("read.jl")
include("iterators.jl")
include("disassemble.jl")

using ArgParse
using Markdown

const VERSION = "0.0.2"

function is_magic_fat(magic::UInt32)
  magic == FAT_MAGIC || magic == FAT_CIGAM
end

function is_magic_64(magic::UInt32)
  magic == MH_MAGIC_64 || magic == MH_CIGAM_64
end

function should_swap_bytes(magic::UInt32)
  magic == MH_CIGAM || magic == MH_CIGAM_64
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
  f, offset, is_64, is_swap, header_pair = read_header(filename)
  pprint(header_pair.first)
end

# --ls option, print out the names of all Load Cmds.
function opt_load_cmd_ls(filename)
  f, offset, is_64, is_swap, header_pair = read_header(filename)
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
function opt_shared_libs(filename)
  f, offset, is_64, is_swap, header_pair = read_header(filename)
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

function opt_objc_classnames(filename)
  f, offset, is_64, is_swap, header_meta = read_header(filename)
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

function opt_disassemble(filename)
  f, offset, is_64, is_swap, header_meta = read_header(filename)
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

function opt_uuid(filename)
  f, offset, is_64, is_swap, header_meta = read_header(filename)
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

function opt_min_sdk(filename)
  f, offset, is_64, is_swap, header_meta = read_header(filename)
  header = header_meta.first
  offset += sizeof(header)
  for i = 1:header.ncmds
    load_cmd = read_generic(LoadCommand, f, offset, is_swap).first
    if in(load_cmd.cmd, [LC_VERSION_MIN_MACOSX, LC_VERSION_MIN_IPHONEOS, LC_VERSION_MIN_WATCHOS, LC_VERSION_MIN_TVOS])
      version_min = read_generic(VersionMinCommand, f, offset, is_swap).first
      println(load_commands[load_cmd.cmd])
      println("Loaded version min: $(version_min.version) $(version_min.sdk)")  
      println("version: $(version_desc(version_min.version))")
      println("sdk: $(version_desc(version_min.sdk))")
    end
    offset += load_cmd.cmdsize
  end
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
      "--disassemble"
        help = "Disassemble the __TEXT section"
        action = :store_true
      "--min-sdk"
        help = "Show the deployment target the binary was compiled for"
        action = :store_true
      "--uuid"
        help = "Print the 128-bit UUID for an image or its corresponding dSYM file."
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
    opt_objc_classnames(filename)
  elseif arg_dict["disassemble"] == true
    opt_disassemble(filename)
  elseif arg_dict["uuid"] == true
    opt_uuid(filename)
  elseif arg_dict["min-sdk"] == true
    opt_min_sdk(filename)
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