require "fiddle/import"
require "fiddle/types"

# This module is a thin wrapper over Win32 API. Use this as follows:
#
# >>> require_relative 'winffi'
# >>> WinFFI.GetMemoryStatus
# {:TotalPhys=>4294496256, :AvailPhys=>1923817472, ... }

module WinFFI

  # https://docs.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-globalmemorystatusex
  module Kernel32
    extend Fiddle::Importer
    dlload "Kernel32.dll"
    include Fiddle::Win32Types
    extern "int GlobalMemoryStatusEx(void*)"
    MemoryStatusEx = struct([
        "DWORD dwLength",
        "DWORD dwMemoryLoad",
        "DWORD64 ullTotalPhys",
        "DWORD64 ullAvailPhys",
        "DWORD64 ullTotalPageFile",
        "DWORD64 ullAvailPageFile",
        "DWORD64 ullTotalVirtual",
        "DWORD64 ullAvailVirtual",
        "DWORD64 ullAvailExtendedVirtual",
    ])
  end

  # https://docs.microsoft.com/en-us/windows/win32/api/psapi/nf-psapi-getperformanceinfo
  module Psapi
    extend Fiddle::Importer
    dlload "Psapi.dll"
    include Fiddle::Win32Types
    extern "BOOL GetPerformanceInfo(void*, DWORD)"
    PERFORMANCE_INFORMATION = struct([
      "DWORD cb",
      "size_t CommitTotal",
      "size_t CommitLimit",
      "size_t CommitPeak",
      "size_t PhysicalTotal",
      "size_t PhysicalAvailable",
      "size_t SystemCache",
      "size_t KernelTotal",
      "size_t KernelPaged",
      "size_t KernelNonpaged",
      "size_t PageSize",
      "DWORD HandleCount",
      "DWORD ProcessCount",
      "DWORD ThreadCount"
    ])
  end

  # https://docs.microsoft.com/en-us/windows/win32/api/lmwksta/nf-lmwksta-netwkstagetinfo
  module NetAPI32
    extend Fiddle::Importer
    dlload "Netapi32.dll"
    include Fiddle::Win32Types
    extern "DWORD NetWkstaGetInfo(void *, DWORD, void*)"
    extern "DWORD NetWkstaUserGetInfo(void*, DWORD, void*)"
    extern "DWORD NetWkstaUserGetInfo(void*)"
    extern "DWORD NetApiBufferFree(void*)"

    WKSTA_INFO_102 = struct([
      "DWORD wki102_platform_id",
      "PVOID wki102_computername",
      "PVOID wki102_langroup",
      "DWORD wki102_ver_major",
      "DWORD wki102_ver_minor",
      "PVOID wki102_lanroot",
      "DWORD wki102_logged_on_users",
    ])
  end

  def self.GetMemoryStatus()
    buf = Kernel32::MemoryStatusEx.malloc
    buf.dwLength = Kernel32::MemoryStatusEx.size
    if Kernel32.GlobalMemoryStatusEx(buf) == 0
      return nil
    end

    return {
        :TotalPhys => buf.ullTotalPhys,
        :AvailPhys => buf.ullAvailPhys,
        :TotalPageFile => buf.ullTotalPageFile,
        :AvailPageFile => buf.ullAvailPageFile,
        :TotalVirtual => buf.ullTotalVirtual,
        :AvailVirtual => buf.ullAvailVirtual,
        :AvailExtendedVirtual => buf.ullAvailExtendedVirtual
    }
  end

  def self.GetWorkstationInfo
    buf = "\0" * Fiddle::SIZEOF_VOIDP
    if NetAPI32.NetWkstaGetInfo(nil, 102, buf) != 0
        return nil
    end
    ptr = buf.unpack('j')[0]
    if ptr == 0
        return nil
    end

    info = NetAPI32::WKSTA_INFO_102.new(ptr)
    ret = {
      :PlatformID => info.wki102_platform_id,
      :VersionMajor => info.wki102_ver_major,
      :VersionMinor => info.wki102_ver_minor,
      :LoggedOnUsers => info.wki102_logged_on_users
    }
    NetAPI32.NetApiBufferFree(ptr)
    return ret
  end

  def self.GetPerformanceInfo()
    buf = Psapi::PERFORMANCE_INFORMATION.malloc
    size = Psapi::PERFORMANCE_INFORMATION.size
    buf.cb = size
    if not Psapi.GetPerformanceInfo(buf, size)
      return nil
    end
    return {
      :CommitTotal => buf.CommitTotal,
      :CommitLimit => buf.CommitLimit,
      :CommitPeak => buf.CommitPeak,
      :PhysicalTotal => buf.PhysicalTotal,
      :PhysicalAvailable => buf.PhysicalAvailable,
      :SystemCache => buf.SystemCache,
      :KernelTotal => buf.KernelTotal,
      :KernelPaged => buf.KernelPaged,
      :KernelNonpaged => buf.KernelNonpaged,
      :PageSize => buf.PageSize,
      :HandleCount => buf.HandleCount,
      :ProcessCount => buf.ProcessCount,
      :ThreadCount => buf.ThreadCount
    }
  end
end
