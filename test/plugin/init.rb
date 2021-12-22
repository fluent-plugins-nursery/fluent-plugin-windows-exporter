require "fluent/plugin/winffi.rb"

# This script shows the meta information for test platforms.
#
# +-------------------------------------------+
# | OS       : Windows 10 Enterprise N        |
# | Version  : 10.0.19043                     |
# | Memory   : 8.0 GB (free: 6.2 GB)         |
# | PageFile : 9.9 GB (free: 7.8 GB)         |
# | Users    : 0                              |
# | Processes: 121                            |
# | Threads  : 824                            |
# +-------------------------------------------+
#
# After the test framework is prepared, we print the above information
# to STDERR. This will be useful to analyze the root cause when some
# tests are failing.

def GB(n)
  return n / 1024.0 / 1024 / 1024
end

def information
  m = WinFFI.GetMemoryStatus()
  i = WinFFI.GetPerformanceInfo()
  w = WinFFI.GetWorkstationInfo()
  r = WinFFI.GetRegistryInfo()

  version  = sprintf("%i.%i.%s", w[:VersionMajor], w[:VersionMinor], r[:CurrentBuildNumber])
  memory   = sprintf("%.1f GB (free: %.1f GB)", GB(m[:TotalPhys]), GB(m[:AvailPhys]))
  pagefile = sprintf("%.1f GB (free: %.1f GB)", GB(m[:TotalPageFile]), GB(m[:AvailPageFile]))

  STDERR.puts("+-------------------------------------------+")
  STDERR.puts("| OS       : %-30s |" % r[:ProductName])
  STDERR.puts("| Version  : %-30s |" % version)
  STDERR.puts("| Memory   : %-30s |" % memory)
  STDERR.puts("| PageFile : %-30s |" % pagefile)
  STDERR.puts("| Users    : %-30i |" % w[:LoggedOnUsers])
  STDERR.puts("| Processes: %-30i |" % i[:ProcessCount])
  STDERR.puts("| Threads  : %-30i |" % i[:ThreadCount])
  STDERR.puts("--------------------------------------------+")
end

information()
