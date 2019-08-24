using Markdown
include("constants.jl")
include("types.jl")
include("utils.jl")
include("read.jl")
include("iterators.jl")
include("disassemble.jl")

using Printf

# Walks entire file system looking for fat files, optionally pass in stop_count
# to stop after a certain number of fat files are found
function walk_filesystem_for_fat_files(stop_count)
  count = 0
  fat_files = String[]
  for (root, dirs, files) in walkdir("/Applications")
    for file in files
      try 
        filepath = joinpath(root, file)
        f = open(filepath)
        seekstart(f)
        magic = read(f, UInt32)
        if magic == FAT_MAGIC || magic == FAT_CIGAM
          push!(fat_files, filepath)
          count += 1
        end
      catch
        # Nothing, we don't care
      end
    end
    if count >= stop_count
      break
    end
  end
  fat_files
end

# walk_filesystem_for_fat_files(2) |> println

# using Libdl 

# # Open dylib
# lib = Libdl.dlopen("./bin/capstonewrapper.dylib")
# sym = Libdl.dlsym(lib, :disassemble_x86_64)

# # Open binary to read
# f = open("./Binaries/ObjcThin")
# seek(f, 0xE10) # __TEXT base offset 
# data = UInt8[]
# readbytes!(f, data, 0xD2) # Read entire contents of __TEXT, 0xD2 is the size.
# println(data)

# # Pass data to capstone wrapper
# #TODO: Need to change the wrapper to output to a passed in reference.
# # Pass in read data, sizeof data, address of first instruction in raw code buffer, num of instructions (Method length)
# ccall(sym, Cint, (Ref{Cuchar}, Csize_t, Culonglong, Csize_t), data, sizeof(data), 0x100000E10, 24)

# # Optional
# Libdl.dlclose(lib)

# println(sym)

# /// Utility function to decode a ULEB128 value.
# static inline uint64_t decodeULEB128(const uint8_t *p, unsigned *n = 0) {
#   const uint8_t *orig_p = p;
#   uint64_t Value = 0;
#   unsigned Shift = 0;
#   do {
#     Value += (*p & 0x7f) << Shift;
#     Shift += 7;
#   } while (*p++ >= 128);
#   if (n)
#     *n = (unsigned)(p - orig_p);
#   return Value;
# }


#TODO: Not sure sizes here, re-address
# seg_index: 0 seg_offset: 0x0 lib_ordinal: 0 type: 0 flags: 0 special_dylib: 1
struct BindRecord
  seg_index::Int64
  seg_offset::Int64
  lib_ordinal::Int64
  type::Int64
  flags::Int64
  symbol_name::String
  
  BindRecord() = new(0,0,0,0,0, "")
  BindRecord(seg_index, seg_offset, lib_ordinal, type, flags, symbol_name) = new(seg_index, seg_offset, lib_ordinal, type, flags, symbol_name)
end

# Replace with proper lens lib if this gets too painful
withSegIndex(b::BindRecord, s::Int64) = BindRecord(s, b.seg_offset, b.lib_ordinal, b.type, b.flags, b.symbol_name)
withSegOffset(b::BindRecord, s::Int64) = BindRecord(b.seg_index, s, b.lib_ordinal, b.type, b.flags, b.symbol_name)
withLibOrdinal(b::BindRecord, s::Int64) = BindRecord(b.seg_index, b.seg_offset, s, b.type, b.flags, b.symbol_name)
withType(b::BindRecord, s::Int64) = BindRecord(b.seg_index, b.seg_offset, b.lib_ordinal, s, b.flags, b.symbol_name)
withFlags(b::BindRecord, s::Int64) = BindRecord(b.seg_index, b.seg_offset, b.lib_ordinal, b.type, s, b.symbol_name)
withSymbolName(b::BindRecord, s::String) = BindRecord(b.seg_index, b.seg_offset, b.lib_ordinal, b.type, b.flags, s)

#TODO: Figure out correct sizes, and remove the casts in this func.
function read_bind_opcodes(f::IOStream, start, length, is_64::Bool)
  seek(f, start)
  endval = start + length
  
  bind_stack = BindRecord[]
  while position(f) < endval
    # define record
    record = BindRecord()
    ptr_size = is_64 ? 8 : 4
    
    #TODO: Only for debugging
    i = 0
    
    # Build the record here
    while true
      curr_byte  = read(f, UInt8)
      curr_opcode = curr_byte & BIND_OPCODE_MASK
      
      println("Curr byte: $(curr_byte), opcode: $(bind_opcodes[curr_opcode])")
      
      if curr_opcode == BIND_OPCODE_SET_DYLIB_ORDINAL_IMM
        val = curr_byte & BIND_IMMEDIATE_MASK
        record = withLibOrdinal(record, Int64(val))
      elseif curr_opcode == BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB
        val = decodeULEB128(f)
        record = withLibOrdinal(record, Int64(val))
      elseif curr_opcode == BIND_OPCODE_SET_DYLIB_SPECIAL_IMM
        #TODO
      elseif curr_opcode == BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM
        symbol = read_cstring(position(f), f)
        println(symbol)
        offset = position(f) + sizeof(symbol) + 1
        seek(f, offset)
        record = withSymbolName(record, symbol)
      elseif curr_opcode == BIND_OPCODE_SET_TYPE_IMM
        val = curr_byte & BIND_IMMEDIATE_MASK
        println(val)
        record = withType(record, Int64(val))
      elseif curr_opcode == BIND_OPCODE_SET_ADDEND_SLEB
        #TODO
        
      elseif curr_opcode == BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB
        
        seg_index = curr_byte & BIND_IMMEDIATE_MASK
        seg_offset = decodeULEB128(f)
        println("Seg index: $seg_index, seg_offset: $seg_offset")
        record = withSegIndex(record, Int64(seg_index))
        record = withSegOffset(record, Int64(seg_offset))
        
      elseif curr_opcode == BIND_OPCODE_ADD_ADDR_ULEB
        
        val = decodeULEB128(f)
        record = withSegOffset(record, Int64(record.seg_offset + val))
        
      elseif curr_opcode == BIND_OPCODE_DO_BIND
        push!(bind_stack, record)
        # jump by platform pointer size, 32, or 64 bits
        record = withSegOffset(record, record.seg_offset + ptr_size)
        
      elseif curr_opcode == BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB
        #TODO
        
      elseif curr_opcode == BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED
        
        push!(bind_stack, record)
        scale = curr_byte & BIND_IMMEDIATE_MASK
        #TODO: Not sure if this is correct
        seg_offset = record.seg_offset + (scale * ptr_size) + ptr_size
        
        scale |> println
        seg_offset |> println
        withSegOffset(record, seg_offset)
        
      elseif curr_opcode  == BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB
        #TODO
      end
      
      #TODO: Remove, only for debugging.
      # break
      i += 1
      if i > 10
        break
      end
    end
    return
  end
end


function do_stuff()
  filename = "/Users/dbeard/ObjCThin"
  f, offset, is_64, is_swap, header_pair = read_header(filename)
  header = header_pair.first
  offset += sizeof(header)
  for i = 1:header.ncmds
    load_cmd = read_generic(LoadCommand, f, offset, is_swap).first
    if in(load_cmd.cmd, [LC_DYLD_INFO, LC_DYLD_INFO_ONLY])
      d = read_generic(DyldInfoCommand, f, offset, is_swap).first
      "Command size: $(d.cmdsize)" |> println
      "RI offset: $(d.rebase_off)" |> println
      "RI size: $(d.rebase_size)" |> println
      "bind off: $(d.bind_off)" |> println
      "bind size: $(d.bind_size)" |> println
      
      println(d)
      read_bind_opcodes(f, d.bind_off, d.bind_size, is_64)
      
      return
    end
    offset += load_cmd.cmdsize
  end
  
  
  
  # Read first byte from rebase offset
  # seek(f, 8192)
  # a = read(f, UInt8)
  # opcode = a & ~REBASE_OPCODE_MASK
  # @printf("0x%0x\n", a)
  # @printf("0x%0x", opcode)
  
end
do_stuff()
