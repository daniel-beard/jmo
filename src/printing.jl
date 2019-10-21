include("types.jl")
include("constants.jl")
include("dyld_info.jl")

using Printf
using Markdown

# This file contains functions for printing out data structures nicely.

#====================================================================#
# Markdown
#====================================================================#

# Outputs a markdown table
# Param is an array of alternating titles + values, e.g.
# ["title1", "val1", "title2", "val2"]
function printmdtable(titlesAndValues::Array{Any})
  titles = Any[]
  values = Any[]
  for (index, val) in pairs(titlesAndValues)
    if index % 2 != 0 
      push!(titles, val)
    else
      push!(values, val)
    end
  end
  table = Markdown.MD(Markdown.Table(Any[titles, values], repeat([:c], length(titles))))
  println(Markdown.rst(table))
end

#====================================================================#
# Pretty Print 
#====================================================================#

function pprint(header::Union{MachHeader, MachHeader64})
  type = isa(header, MachHeader) ? "MachHeader" : "MachHeader64"
  println(type)
  t = Any[]
  push!(t, "magic", @sprintf("0x%0x", header.magic))
  push!(t, "cputype", header_cpu_type_desc(header))
  push!(t, "cpusubtype", header_cpu_subtype_desc(header))
  push!(t, "filetype", header_filetype_desc(header))
  push!(t, "ncmds", @sprintf("%d", header.ncmds))
  push!(t, "sizeofcmds", @sprintf("%d", header.sizeofcmds))
  push!(t, "flags", header_flags_desc(header))
  printmdtable(t)
end

function pprint(fatHeader::FatHeader)
  println("FatHeader")
  t = Any[]
  push!(t, "magic", @sprintf("0x%0x", fatHeader.magic))
  push!(t, "nfat_arch", @sprintf("%d", fatHeader.nfat_arch))
  printmdtable(t)
end

function pprint(fatArch::FatArch)
  println("FatArch")
  t = Any[]
  push!(t, "cputype", header_cpu_type_desc(fatArch))
  push!(t, "cpusubtype", @sprintf("0x%0x", fatArch.cpusubtype))
  push!(t, "offset", @sprintf("0x%0x", fatArch.offset))
  push!(t, "size", @sprintf("%d", fatArch.size))
  push!(t, "align", @sprintf("%d", fatArch.align))
  printmdtable(t)
end

# Pretty print for binding & lazy binding info.
function pprint(dylibs::Vector{Pair{DylibCommand, MetaStruct}}, segments::Vector{SegmentCommand64}, records::Vector{BindRecord}; is_lazy = false)
  @printf("description\tvalue\n")
  for record in records
    (dylib, dylib_meta) = dylibs[record.lib_ordinal]
    offset = UInt32(dylib_meta.offset + dylib.name)
    dylib_name = basename(read_cstring(offset, dylib_meta.f))
    bind_type = get(bind_types, record.type, string(record.type))
    segment = segments[record.seg_index + 1]
    addr = segment.vmaddr + record.seg_offset
    if is_lazy
      # No bind types for lazy binding info
      @printf("%s\t0x%08x\t(%s)\t%s\n", String(segment.segname), addr, dylib_name, record.symbol_name)
    else 
      @printf("%s\t0x%08x\t%s\t%s\t(%s)\t%s\n", String(segment.segname), addr, bind_type, "TODO", dylib_name, record.symbol_name)
    end
  end
  println()
end

# Base.show implementations
####################################

function Base.show(io::IO, lc::LoadCommand)
  println(io, load_cmd_desc(lc))
end

function Base.show(io::IO, h::Union{MachHeader, MachHeader64})
  print(io, "magic\t\tcputype\t\tcpusubtype\tfiletype\tncmds\t\tsizeofcmds\tflags\t\treserved\n")
  print(io, "$(repr(h.magic))\t$(h.cputype)\t$(h.cpusubtype)\t$(h.filetype)\t\t$(h.ncmds)\t\t$(h.sizeofcmds)\t\t$(h.flags)\t\t$(h.reserved)\n")
end

function Base.show(io::IO, uuid::Pair{UUIDCommand, MetaStruct})
  uuid = uuid.first
  uuid_val = uuid.uuid
  string = @sprintf("%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X", uuid_val...)
  println(io, "LC_UUID:")
  println(io, string)
end

function Base.show(io::IO, version::Pair{VersionMinCommand, MetaStruct})
  map = @dict[LC_VERSION_MIN_MACOSX,LC_VERSION_MIN_IPHONEOS,LC_VERSION_MIN_WATCHOS,LC_VERSION_MIN_TVOS]
  version = version.first
  name = get(map, version.cmd, "UNKNOWN")
  println(io, "$(name):")
  println(io, "Version: $(version_desc(version.version))")
  println(io, "SDK: $(version_desc(version.sdk))")
end

function Base.show(io::IO, dylib::Pair{DylibCommand, MetaStruct})
  (dylib, meta) = dylib
  offset = UInt32(meta.offset + dylib.name)
  name = read_cstring(offset, meta.f)
  compat_version = version_desc(dylib.compatibility_version)
  curr_version = version_desc(dylib.current_version)
  print(io, "\t$(name) (compatibility version $(compat_version), current version $(curr_version))")
end

