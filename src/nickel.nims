import strutils
switch("path", "..")
switch("define", "ssl")

hint("XDeclaredButNotUsed", false)

warning("GcUnsafe2", false)
warning("UnusedImport", false)

# Кросс-компиляция под Windows с помощью mingw
when defined(crosswin):
  switch("cc", "gcc")
  let mingwExe = "x86_64-w64-mingw32-gcc"
  switch("gcc.linkerexe", mingwExe)
  switch("gcc.exe", mingwExe)
  switch("gcc.path", findExe(mingwExe).rsplit("/", 1)[0])
  switch("gcc.options.linker", "")
  switch("os", "windows")
  switch("define", "windows")