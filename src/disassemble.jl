using Libdl 


function dissassemble(offset::UInt32, size::UInt64, address::UInt64, f::IOStream)

  # Open dylib
  lib = Libdl.dlopen("./bin/capstonewrapper.dylib")
  sym = Libdl.dlsym(lib, :disassemble_x86_64)

  # Open binary to read
  seek(f, offset) # __TEXT base offset 
  data = UInt8[]
  readbytes!(f, data, size) # Read entire contents of __TEXT, size is the size.

  # Pass data to capstone wrapper
  #TODO: Need to change the wrapper to output to a passed in reference.
  # Pass in read data, sizeof data, address of first instruction in raw code buffer, num of instructions (Method length)
  ccall(sym, Cint, (Ref{Cuchar}, Csize_t, Culonglong, Csize_t), data, sizeof(data), address, 0)

  # Optional
  Libdl.dlclose(lib)

  println(sym)
end