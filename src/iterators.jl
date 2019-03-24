
include("constants.jl")
include("types.jl")
include("read.jl")

# Segment Iterator
###########################################################

struct SegmentIterator
  header::Union{Pair{MachHeader, MetaStruct}, Pair{MachHeader64, MetaStruct}}
  is_64::Bool
  is_swap::Bool
end

struct SegmentIteratorState
  offset::Int64
  cmd_index::Int64
end

# Handles both types of Base.iterate methods
# This function handles the work of iterating over segment commands.
function do_iteration(si::SegmentIterator, state::Union{Nothing, SegmentIteratorState})
  meta = si.header.second
  header = si.header.first
  offset = (state === nothing) ? (meta.offset + sizeof(header)) : state.offset
  cmd_index = (state === nothing) ? 1 : state.cmd_index
  segment_command = nothing
  while cmd_index < header.ncmds
    load_cmd = read_generic(LoadCommand, meta.f, offset, si.is_swap).first
    cmd_index += 1
    lcSeg = si.is_64 ? LC_SEGMENT_64 : LC_SEGMENT
    if load_cmd.cmd == lcSeg
      T = (lcSeg == LC_SEGMENT) ? SegmentCommand : SegmentCommand64
      segment_command = read_generic(T, meta.f, offset, si.is_swap)
      offset += load_cmd.cmdsize
      return (segment_command, SegmentIteratorState(offset, cmd_index))
    end
    offset += load_cmd.cmdsize
  end
  return nothing
end

# Return tuple of first item + state or nothing
function Base.iterate(si::SegmentIterator)
  do_iteration(si, nothing)
end

# Returns either a tuple of the next item and next state or nothing if no items remain
function Base.iterate(si::SegmentIterator, state::SegmentIteratorState)
  do_iteration(si, state)
end

IteratorSize(SegmentIterator) = SizeUnknown()


# Section Iterator
###########################################################s

struct SectionIterator
  segment::Union{Pair{SegmentCommand, MetaStruct}, Pair{SegmentCommand64, MetaStruct}}
  is_64::Bool
  is_swap::Bool
end

struct SectionIteratorState
  offset::Int64
  index::Int64
end

# Handles both types of Base.iterate methods
# This function handles the work of iterating over section commands.
function do_iteration(si::SectionIterator, state::Union{Nothing, SectionIteratorState})
  meta = si.segment.second
  segment = si.segment.first
  offset = (state === nothing) ? (meta.offset + sizeof(segment)) : state.offset
  index = (state === nothing) ? 1 : state.index
  section_command = nothing
  while index < segment.nsects
    T = si.is_64 ? Section64 : Section
    section_pair = read_generic(T, meta.f, offset, si.is_swap)
    index += 1
    offset += sizeof(section_pair.first)
    return (section_pair, SectionIteratorState(offset, index))
  end
  return nothing
end

# Return tuple of first item + state or nothing
function Base.iterate(si::SectionIterator)
  do_iteration(si, nothing)
end

# Returns either a tuple of the next item and next state or nothing if no items remain
function Base.iterate(si::SectionIterator, state::SectionIteratorState)
  do_iteration(si, state)
end