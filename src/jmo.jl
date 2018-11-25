
module JMO 

include("constants.jl")
include("types.jl")

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

# reads a type from specified offset for given IO object
function load_bytes(f::IOStream, offset, T)
  seek(f, offset)
  read(f, T)
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

# iostream, offset, is_swap
function read_load_command(f::IOStream, offset::Int64, is_swap::Bool)
  T, tfields = LoadCommand, fieldnames(LoadCommand)
  seek(f, offset)
  return T(
    is_swap ? bswap(read(f, fieldtype(T, 1))) : read(f, fieldtype(T, 1)),
    is_swap ? bswap(read(f, fieldtype(T, 2))) : read(f, fieldtype(T, 2)))
end

# Reads a single SegmentCommand64, or SegmentCommand, based on passed in T
function read_segment_command(T, f::IOStream, offset::Int64, is_swap::Bool)
  seek(f, offset)
  cmd       = is_swap ? bswap(read(f, fieldtype(T, 1))) : read(f, fieldtype(T, 1))
  cmdsize   = is_swap ? bswap(read(f, fieldtype(T, 2))) : read(f, fieldtype(T, 2))
  segname   = is_swap ? bswap(read(f, fieldtype(T, 3))) : read(f, fieldtype(T, 3))
  vmaddr    = is_swap ? bswap(read(f, fieldtype(T, 4))) : read(f, fieldtype(T, 4))
  vmsize    = is_swap ? bswap(read(f, fieldtype(T, 5))) : read(f, fieldtype(T, 5))
  fileoff   = is_swap ? bswap(read(f, fieldtype(T, 6))) : read(f, fieldtype(T, 6))
  filesize  = is_swap ? bswap(read(f, fieldtype(T, 7))) : read(f, fieldtype(T, 7))
  maxprot   = is_swap ? bswap(read(f, fieldtype(T, 8))) : read(f, fieldtype(T, 8))
  initprot  = is_swap ? bswap(read(f, fieldtype(T, 9))) : read(f, fieldtype(T, 9))
  nsects    = is_swap ? bswap(read(f, fieldtype(T, 10))) : read(f, fieldtype(T, 10))
  flags     = is_swap ? bswap(read(f, fieldtype(T, 11))) : read(f, fieldtype(T, 11))
  return T(cmd, cmdsize, segname, vmaddr, vmsize, fileoff, filesize, maxprot, initprot, nsects, flags)
end

# iostream, offset, header type, ncmds, is_swap
# Don't need is_64, can interpret from LC_COMMAND / LC_COMMAND_64
# Reads all segment commands
function read_segment_commands(f::IOStream, load_commands_offset::Int64, ncmds::UInt32, is_swap::Bool)
  actual_offset = load_commands_offset
  for i = 0:ncmds
    load_cmd = read_load_command(f, actual_offset, is_swap)
    
    # Load SegmentCommand && SegmentCommand64 values
    # Since only the types of fields change, the fieldtype's handle that.
    if load_cmd.cmd == LC_SEGMENT_64
      segment_command = read_segment_command(SegmentCommand64, f, actual_offset, is_swap)
      segname_string = String(segment_command.segname)
      println("Segname: $(segname_string)")
    elseif load_cmd.cmd == LC_SEGMENT
      segment_command = read_segment_command(SegmentCommand, f, actual_offset, is_swap)
      segname_string = String(segment_command.segname)
      println("Segname: $(segname_string)")
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
  
  # read segment commands
  load_cmds = read_segment_commands(f, offset, header.ncmds, is_swap)
  println(load_cmds)
  
  close(f)
end

openFile("/Users/dbeard/Binary")

end # module