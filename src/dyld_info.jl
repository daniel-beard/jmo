
include("utils.jl")
include("read.jl")

#====================================================================#
# Functions for operating on dyld info of an image.
#====================================================================#
# 

#TODO: Not sure sizes here, re-address
# seg_index: 0 seg_offset: 0x0 lib_ordinal: 0 type: 0 flags: 0 special_dylib: 1
struct BindRecord
  seg_index::Int64
  seg_offset::UInt64
  lib_ordinal::Int64
  addend::Int64
  type::Int64
  flags::Int64
  symbol_name::String
  
  BindRecord() = new(0,0,0,0,0,0, "")
  BindRecord(seg_index, seg_offset, lib_ordinal, addend, type, flags, symbol_name) = new(seg_index, seg_offset, lib_ordinal, addend, type, flags, symbol_name)
end

#TODO: Replace with proper lens lib if this gets too painful
withSegIndex(b::BindRecord, s::Int64) = BindRecord(s, b.seg_offset, b.lib_ordinal, b.addend, b.type, b.flags, b.symbol_name)
withSegOffset(b::BindRecord, s::UInt64) = BindRecord(b.seg_index, s, b.lib_ordinal, b.addend, b.type, b.flags, b.symbol_name)
withLibOrdinal(b::BindRecord, s::Int64) = BindRecord(b.seg_index, b.seg_offset, s, b.addend, b.type, b.flags, b.symbol_name)
withAddend(b::BindRecord, s::Int64) = BindRecord(b.seg_index, b.seg_offset, b.lib_ordinal, s, b.type, b.flags, b.symbol_name)
withType(b::BindRecord, s::Int64) = BindRecord(b.seg_index, b.seg_offset, b.lib_ordinal, b.addend, s, b.flags, b.symbol_name)
withFlags(b::BindRecord, s::Int64) = BindRecord(b.seg_index, b.seg_offset, b.lib_ordinal, b.addend, b.type, s, b.symbol_name)
withSymbolName(b::BindRecord, s::String) = BindRecord(b.seg_index, b.seg_offset, b.lib_ordinal, b.addend, b.type, b.flags, s)

#====================================================================#
# Binding Opcodes 
#====================================================================#

#TODO: Figure out correct sizes, and remove the casts in this func.
function read_bind_opcodes(f::IOStream, start, length, is_64::Bool)
  seek(f, start)
  endval = start + length
  ptr_size = is_64 ? 8 : 4
  
  bind_stack = BindRecord[]
  while position(f) < endval
    # define record
    record = BindRecord()
    
    # Build the record here
    while true
      curr_byte  = read(f, UInt8)
      curr_opcode = curr_byte & BIND_OPCODE_MASK
      
      println("Curr byte: $(curr_byte), opcode: $(bind_opcodes[curr_opcode])")
      
      if curr_opcode == BIND_OPCODE_SET_DYLIB_ORDINAL_IMM
        val = curr_byte & BIND_IMMEDIATE_MASK
        record = withLibOrdinal(record, Int64(val))
        println(val)
      elseif curr_opcode == BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB
        val = decodeULEB128(f)
        record = withLibOrdinal(record, Int64(val))
        println(val)
      elseif curr_opcode == BIND_OPCODE_SET_DYLIB_SPECIAL_IMM
        immediate = curr_byte & BIND_IMMEDIATE_MASK
        record = withLibOrdinal(record, Int64(immediate))
        println(immediate)
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
        val = decodeSLEB128(f)
        record = withAddend(record, val)
      elseif curr_opcode == BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB
        
        seg_index = curr_byte & BIND_IMMEDIATE_MASK
        seg_offset = decodeULEB128(f)
        println("Seg index: $seg_index, seg_offset: $seg_offset")
        record = withSegIndex(record, Int64(seg_index))
        record = withSegOffset(record, seg_offset)
        
      elseif curr_opcode == BIND_OPCODE_ADD_ADDR_ULEB
        
        val = decodeULEB128(f)
        record = withSegOffset(record, record.seg_offset + val)
        @printf("0x%0x\n", val)
        
      elseif curr_opcode == BIND_OPCODE_DO_BIND
        push!(bind_stack, record)
        # jump by platform pointer size, 32, or 64 bits
        record = withSegOffset(record, record.seg_offset + ptr_size)
        
      elseif curr_opcode == BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB
        
        push!(bind_stack, record)
        offset = decodeULEB128(f)
        seg_offset = record.seg_offset + offset
        
      #TODO: Should be correct now, but double check when you are removing the comments
      # or wrapping them in a verbose switch.
      elseif curr_opcode == BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED
        
        push!(bind_stack, record)
        immediate = curr_byte & BIND_IMMEDIATE_MASK
        offset = (immediate * ptr_size + ptr_size)
        seg_offset = record.seg_offset + offset
        @printf("ptrsize: %d 0x%x\n", ptr_size, ptr_size)
        @printf("immediate: 0x%x offset: 0x%x segoffset: 0x%x\n", immediate, offset, seg_offset)
        seg_offset |> println
        record = withSegOffset(record, seg_offset)
        
      elseif curr_opcode == BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB
        
        count = decodeULEB128(f)
        skip = decodeULEB128(f)
        
        @printf("count: %d skip: %d 0x%x\n", count, skip, skip)
        
        for i = 1:count
          push!(bind_stack, record)
          seg_offset = record.seg_offset + ptr_size + skip
          record = withSegOffset(record, seg_offset)
          println("binding record")
        end

      elseif curr_opcode == BIND_OPCODE_DONE
        break
      end
    end
    return
  end
end
