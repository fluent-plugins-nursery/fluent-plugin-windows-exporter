require "helper"
require "fluent/plugin/winffi.rb"

# Since the actual information (memory amount, OS version etc.) varies
# depending on platforms, this test only performs minimum sanity
# checks.

class WinFFITest < Test::Unit::TestCase
  def test_GetMemoryStatus
    mem = WinFFI.GetMemoryStatus()
    assert(mem[:TotalPhys] > 0)
    assert(mem[:TotalPageFile] > 0)
    assert(mem[:TotalVirtual] > 0)
  end

  def test_GetPerformanceInfo
    perf = WinFFI.GetPerformanceInfo()
    assert(perf[:CommitTotal] > 0)
    assert(perf[:PhysicalTotal] > 0)
    assert(perf[:KernelTotal] > 0)
  end

  def test_GetWorkStationInfo
    work = WinFFI.GetWorkstationInfo()
    assert(work[:VersionMajor] > 0)
  end

  def test_GetRegistryInfo
    reg = WinFFI.GetRegistryInfo()
    assert_not_nil(reg[:ProductName])
  end
end
