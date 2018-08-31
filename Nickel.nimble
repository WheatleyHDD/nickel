version       = "1.1.0"
author        = "Daniil Yarancev"
description   = "Nickel - command bot for largest CIS social network - VKontakte"
license       = "MIT"
srcDir        = "src"
bin           = @["nickel"]

requires "nim >= 0.18.1", "mathexpr", "chronicles", "https://github.com/Yardanico/parsetoml"
when defined(nimdistros):
  import distros
  if detectOs(Ubuntu):
    foreignDep "libssl-dev"
  else:
    foreignDep "openssl"
