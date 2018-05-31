import strutils
switch("path", "..")
switch("define", "ssl")

hint("User", false)
hint("XDeclaredButNotUsed", false)
hint("Pattern", false)
warning("ProveField", false)
warning("ProveInit", false)
warning("ShadowIdent", false)
warning("GcUnsafe", false)
warning("GcUnsafe2", false)

# Конфигурация библиотеки Chronicles
switch("define", "chronicles_sinks:textlines[stdout]")
switch("define", "chronicles_runtime_filtering:on")
when defined(windows):
  switch("define", "chronicles_colors:NativeColors")

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