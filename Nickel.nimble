version       = "1.0.0"
author        = "Daniil Yarancev"
description   = "Nickel - command bot for largest CIS social network - VKontakte"
license       = "MIT"
srcDir = "src"
bin = @["nickel"]

requires "nim >= 0.17.3"

when defined(nimdistros):
  import distros
  if detectOs(Ubuntu):
    foreignDep "libssl-dev"
  else:
    foreignDep "openssl"
