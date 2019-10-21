
include("utils.jl")
include("read.jl")
include("types.jl")

using Printf

#====================================================================#
# Functions for operating on dyld info of an image.
#====================================================================#

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
function read_bind_opcodes(f::IOStream, start, length, is_64::Bool; print_op_codes = false)
  seek(f, start)
  endval = start + length
  ptr_size = is_64 ? 8 : 4
  
  bind_stack = BindRecord[]
  while position(f) < endval
    # define record
    record = BindRecord()
    
    # Build the record here
    while true && position(f) < endval
      curr_byte  = read(f, UInt8)
      curr_opcode = curr_byte & BIND_OPCODE_MASK
      rel_offset = @sprintf("0x%04x", position(f) - start)
      opcode_name = bind_opcodes[curr_opcode]

      if curr_opcode == BIND_OPCODE_SET_DYLIB_ORDINAL_IMM
        val = curr_byte & BIND_IMMEDIATE_MASK
        record = withLibOrdinal(record, Int64(val))
        print_op_codes && @printf("%s %s(%ld)\n", rel_offset, opcode_name, val)
      elseif curr_opcode == BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB
        val = decodeULEB128(f)
        record = withLibOrdinal(record, Int64(val))
        print_op_codes && @printf("%s %s(%ld)\n", rel_offset, opcode_name, val)
      elseif curr_opcode == BIND_OPCODE_SET_DYLIB_SPECIAL_IMM
        immediate = curr_byte & BIND_IMMEDIATE_MASK
        record = withLibOrdinal(record, Int64(immediate))
        print_op_codes && @printf("%s %s(%ld)\n", rel_offset, opcode_name, immediate)
      elseif curr_opcode == BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM
        symbol = read_cstring(position(f), f)
        immediate = curr_byte & BIND_IMMEDIATE_MASK
        bind_flag = get(bind_symbol_flags, immediate, 0)
        offset = position(f) + sizeof(symbol) + 1
        seek(f, offset)
        record = withSymbolName(record, symbol)
        print_op_codes && @printf("%s %s(0x%02x, %s)\n", rel_offset, opcode_name, bind_flag, symbol)
      elseif curr_opcode == BIND_OPCODE_SET_TYPE_IMM
        val = curr_byte & BIND_IMMEDIATE_MASK
        record = withType(record, Int64(val))
        print_op_codes && @printf("%s %s(%ld)\n", rel_offset, opcode_name, val)
      elseif curr_opcode == BIND_OPCODE_SET_ADDEND_SLEB
        val = decodeSLEB128(f)
        record = withAddend(record, val)
        print_op_codes && @printf("%s %s(%ld)\n", rel_offset, opcode_name, val)
      elseif curr_opcode == BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB
        seg_index = curr_byte & BIND_IMMEDIATE_MASK
        seg_offset = decodeULEB128(f)
        record = withSegIndex(record, Int64(seg_index))
        record = withSegOffset(record, seg_offset)
        print_op_codes && @printf("%s %s(0x%02x, 0x%08x)\n", rel_offset, opcode_name, seg_index, seg_offset)
      elseif curr_opcode == BIND_OPCODE_ADD_ADDR_ULEB
        #TODO: Output here is not correct.
        # Got 0xffffffffffffffc8 expected 0xFFFFFFC8)
        val = decodeULEB128(f)
        record = withSegOffset(record, record.seg_offset + val)
        print_op_codes && @printf("%s %s(0x%04x)\n", rel_offset, opcode_name, val)
      elseif curr_opcode == BIND_OPCODE_DO_BIND
        push!(bind_stack, record)
        # jump by platform pointer size, 32, or 64 bits
        record = withSegOffset(record, record.seg_offset + ptr_size)
        print_op_codes && @printf("%s %s()\n", rel_offset, opcode_name)
      elseif curr_opcode == BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB
        push!(bind_stack, record)
        offset = decodeULEB128(f)
        seg_offset = record.seg_offset + offset
        print_op_codes && @printf("%s %s(0x%08x)\n", rel_offset, opcode_name, offset)
      elseif curr_opcode == BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED
        push!(bind_stack, record)
        immediate = curr_byte & BIND_IMMEDIATE_MASK
        offset = (immediate * ptr_size + ptr_size)
        seg_offset = record.seg_offset + offset
        record = withSegOffset(record, seg_offset)
        print_op_codes && @printf("%s %s(0x%08x)\n", rel_offset, opcode_name, offset)
      elseif curr_opcode == BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB
        count = decodeULEB128(f)
        skip = decodeULEB128(f)
        print_op_codes && @printf("%s %s(%ld, 0x%08x)\n", rel_offset, opcode_name, count, skip)
        
        for i = 1:count
          push!(bind_stack, record)
          seg_offset = record.seg_offset + ptr_size + skip
          record = withSegOffset(record, seg_offset)
        end

      elseif curr_opcode == BIND_OPCODE_DONE
        continue
      else
        assert(false, "Unknown opcode! $(curr_opcode)")
      end
    end
    return bind_stack
  end
end
