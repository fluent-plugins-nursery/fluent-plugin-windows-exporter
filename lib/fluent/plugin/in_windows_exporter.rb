#
# Copyright 2021- Fujimoto Seiji, Fukuda Daijiro
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/input"
require_relative "winffi"
require_relative "hkey_perf_data_reader"

module Fluent
  module Plugin
    class WindowsExporterInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("windows_exporter", self)

      helpers :timer

      desc "Tag of the output events"
      config_param :tag, :string, default: nil
      desc "The interval time between data collection"
      config_param :scrape_interval, :time, default: 5
      desc "Enable cpu collector"
      config_param :cpu, :bool, default: true
      desc "Enable disk collector"
      config_param :logical_disk, :bool, default: true
      desc "Enable memory collector"
      config_param :memory, :bool, default: true
      desc "Enable network collector"
      config_param :net, :bool, default: true
      desc "Enable time collector"
      config_param :time, :bool, default: true
      desc "Enable OS collector"
      config_param :os, :bool, default: true

      def configure(conf)
        super
        @cache = nil
        @hkey_perf_data_reader = HKeyPerfDataReader::Reader.new

        @collectors = []
        @collectors << method(:collect_cpu) if @cpu
        #@collectors << method(:collect_logical_disk) if @logical_disk
        @collectors << method(:collect_memory) if @memory
        #@collectors << method(:collect_net) if @net
        @collectors << method(:collect_time) if @time
        @collectors << method(:collect_os) if @os
      end

      def start
        super
        timer_execute(:in_windows_exporter, @scrape_interval, &method(:on_timer))
      end

      def shutdown
        super
      end

      def on_timer
        now = Fluent::EventTime.now
        update_cache()
        es = Fluent::MultiEventStream.new
        for method in @collectors do
            begin
              for record in method.call() do
                  es.add(now, record)
              end
            rescue => e
              $log.error(e.message)
              $log.error_backtrace
            end
        end
        router.emit_stream(@tag, es)
      end

      def update_cache
        @cache = @hkey_perf_data_reader.read
      end

      def collect_cpu
        records = []
        for core in @cache["Processor Information"].instances do
            if core.name.downcase.include?("_total")
                next
            end
            records += [
                {
                    :type => "gauge",
                    :name => "windows_cpu_cstate_seconds_total",
                    :desc => "Time spent in low-power idle state",
                    :labels => {"core" => core.name, "state" => "c1" },
                    :value => core.counters["% C1 Time"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_cstate_seconds_total",
                    :desc => "Time spent in low-power idle state",
                    :labels => {"core" => core.name, "state" => "c2" },
                    :value => core.counters["% C2 Time"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_cstate_seconds_total",
                    :desc => "Time spent in low-power idle state",
                    :labels => {"core" => core.name, "state" => "c3" },
                    :value => core.counters["% C3 Time"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_time_total",
                    :desc => "Time that processor spent in different modes (idle, user, system, ...)",
                    :labels => {"core" => core.name, "mode" => "idle"},
                    :value => core.counters["% Idle Time"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_time_total",
                    :desc => "Time that processor spent in different modes (idle, user, system, ...)",
                    :labels => {"core" => core.name, "mode" => "interrupt"},
                    :value => core.counters["% Interrupt Time"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_time_total",
                    :desc => "Time that processor spent in different modes (idle, user, system, ...)",
                    :labels => {"core" => core.name, "mode" => "dpc"},
                    :value => core.counters["% DPC Time"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_time_total",
                    :desc => "Time that processor spent in different modes (idle, user, system, ...)",
                    :labels => {"core" => core.name, "mode" => "privileged"},
                    :value => core.counters["% Privileged Time"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_time_total",
                    :desc => "Time that processor spent in different modes (idle, user, system, ...)",
                    :labels => {"core" => core.name, "mode" => "user"},
                    :value => core.counters["% User Time"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_interrupts_total",
                    :desc => "Total number of received and serviced hardware interrupts",
                    :labels => {"core" => core.name},
                    :value => core.counters["Interrupts/sec"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_dpcs_total",
                    :desc => "Total number of received and serviced deferred procedure calls (DPCs)",
                    :labels => {"core" => core.name},
                    :value => core.counters["DPCs Queued/sec"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_clock_interrupts_total",
                    :desc => "Total number of received and serviced clock tick interrupts",
                    :labels => {"core" => core.name},
                    :value => core.counters["Clock Interrupts/sec"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_idle_break_events_total",
                    :desc => "Total number of time processor was woken from idle",
                    :labels => {"core" => core.name},
                    :value => core.counters["Idle Break Events/sec"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_parking_status",
                    :desc => "Parking Status represents whether a processor is parked or not",
                    :labels => {"core" => core.name},
                    :value => core.counters["Parking Status"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_core_frequency_mhz",
                    :desc => "Core frequency in megahertz",
                    :labels => {"core" => core.name},
                    :value => core.counters["Processor Frequency"]
                },
                {
                    :type => "gauge",
                    :name => "windows_cpu_processor_performance",
                    :desc => "Processor Performance is the average performance of the processor while it is executing instructions, as a percentage of the nominal performance of the processor. On some processors, Processor Performance may exceed 100%",
                    :labels => {"core" => core.name},
                    :value => core.counters["% Processor Performance"]
                }
            ]
        end
        return records
      end

      def collect_memory
        # Now just test HKeyPerfDataReader
        return [
          {
            :type => "gauge",
            :name => "windows_memory_available_bytes",
            :desc =>  "The amount of physical memory immediately available for allocation to a process or for system use. It is equal to the sum of memory assigned to the standby (cached), free and zero page lists (AvailableBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Available Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_cache_bytes",
            :desc =>  "(CacheBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Cache Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_cache_bytes_peak",
            :desc =>  "(CacheBytesPeak)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Cache Bytes Peak"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_cache_faults_total",
            :desc =>  "(CacheFaultsPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Cache Faults/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_commit_limit",
            :desc =>  "(CommitLimit)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Commit Limit"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_committed_bytes",
            :desc =>  "(CommittedBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Committed Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_demand_zero_faults_total",
            :desc =>  "The number of zeroed pages required to satisfy faults. Zeroed pages, pages emptied of previously stored data and filled with zeros, are a security feature of Windows that prevent processes from seeing data stored by earlier processes that used the memory space (DemandZeroFaults)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Demand Zero Faults/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_free_and_zero_page_list_bytes",
            :desc =>  "(FreeAndZeroPageListBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Free & Zero Page List Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_free_system_page_table_entries",
            :desc =>  "(FreeSystemPageTableEntries)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Free System Page Table Entries"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_modified_page_list_bytes",
            :desc =>  "(ModifiedPageListBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Modified Page List Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_page_faults_total",
            :desc =>  "(PageFaultsPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Page Faults/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_swap_page_reads_total",
            :desc =>  "Number of disk page reads (a single read operation reading several pages is still only counted once) (PageReadsPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Page Reads/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_swap_pages_read_total",
            :desc =>  "Number of pages read across all page reads (ie counting all pages read even if they are read in a single operation) (PagesInputPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Pages Input/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_swap_pages_written_total",
            :desc =>  "Number of pages written across all page writes (ie counting all pages written even if they are written in a single operation) (PagesOutputPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Pages Output/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_swap_page_operations_total",
            :desc =>  "Total number of swap page read and writes (PagesPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Pages/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_swap_page_writes_total",
            :desc =>  "Number of disk page writes (a single write operation writing several pages is still only counted once) (PageWritesPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Page Writes/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_pool_nonpaged_allocs_total",
            :desc =>  "The number of calls to allocate space in the nonpaged pool. The nonpaged pool is an area of system memory area for objects that cannot be written to disk, and must remain in physical memory as long as they are allocated (PoolNonpagedAllocs)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Pool Nonpaged Allocs"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_pool_nonpaged_bytes_total",
            :desc =>  "(PoolNonpagedBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Pool Nonpaged Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_pool_paged_allocs_total",
            :desc =>  "(PoolPagedAllocs)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Pool Paged Allocs"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_pool_paged_bytes",
            :desc =>  "(PoolPagedBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Pool Paged Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_pool_paged_resident_bytes",
            :desc =>  "(PoolPagedResidentBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Pool Paged Resident Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_standby_cache_core_bytes",
            :desc =>  "(StandbyCacheCoreBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Standby Cache Core Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_standby_cache_normal_priority_bytes",
            :desc =>  "(StandbyCacheNormalPriorityBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Standby Cache Normal Priority Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_standby_cache_reserve_bytes",
            :desc =>  "(StandbyCacheReserveBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Standby Cache Reserve Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_system_cache_resident_bytes",
            :desc =>  "(SystemCacheResidentBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["System Cache Resident Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_system_code_resident_bytes",
            :desc =>  "(SystemCodeResidentBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["System Code Resident Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_system_code_total_bytes",
            :desc =>  "(SystemCodeTotalBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["System Code Total Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_system_driver_resident_bytes",
            :desc =>  "(SystemDriverResidentBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["System Driver Resident Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_system_driver_total_bytes",
            :desc =>  "(SystemDriverTotalBytes)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["System Driver Total Bytes"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_transition_faults_total",
            :desc =>  "(TransitionFaultsPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Transition Faults/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_transition_pages_repurposed_total",
            :desc =>  "(TransitionPagesRePurposedPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Transition Pages RePurposed/sec"]
          },
          {
            :type => "gauge",
            :name => "windows_memory_write_copies_total",
            :desc =>  "The number of page faults caused by attempting to write that were satisfied by copying the page from elsewhere in physical memory (WriteCopiesPersec)",
            :labels => {},
            :value => @cache["Memory"].instances[0].counters["Write Copies/sec"]
          }
        ]
      end

      def collect_time
        return [{
            :type => "gauge",
            :name => "windows_time",
            :desc =>  "System time in seconds since epoch (1970)",
            :labels => {},
            :timestamp => Fluent::EventTime.now.to_f,
            :value => Fluent::EventTime.now.to_f
        }]
      end

      def collect_os
        mem = WinFFI.GetMemoryStatus()
        work = WinFFI.GetWorkstationInfo()
        perf = WinFFI.GetPerformanceInfo()
        reg = WinFFI.GetRegistryInfo()

        pfusage = 0
        for ins in @cache["Paging File"].instances do
          unless ins.name.downcase.include?("_total")
            pfusage += ins.counters["% Usage"]
          end
        end

        return [
          {
            :type => "gauge",
            :name => "windows_os_info",
            :desc => "OperatingSystem.Caption, OperatingSystem.Version",
            :labels => {
              :product => "Microsoft #{reg[:ProductName]}",
              :version => "#{work[:VersionMajor]}.#{work[:VersionMinor]}.#{reg[:CurrentBuildNumber]}"
            },
            :value => 1.0
          },
          {
            :type => "gauge",
            :name => "windows_os_physical_memory_free_bytes",
            :desc => "OperatingSystem.FreePhysicalMemory",
            :labels => {},
            :value => mem[:AvailPhys]
          },
          {
            :type => "gauge",
            :name => "windows_os_time",
            :desc => "OperatingSystem.LocalDateTime",
            :labels => {},
            :value => Fluent::EventTime.now.to_f
          },
          {
            :type => "gauge",
            :name => "windows_os_timezone",
            :desc => "OperatingSystem.LocalDateTime",
            :labels => {:timezone => Time.now.zone},
            :value => 1.0
          },
          {
            :type => "gauge",
            :name => "windows_os_paging_free_bytes",
            :desc => "OperatingSystem.FreeSpaceInPagingFiles",
            :labels => {},
            :value =>  reg[:PagingLimitBytes] - pfusage * perf[:PageSize]
          },
          {
            :type => "gauge",
            :name => "windows_os_virtual_memory_free_bytes",
            :desc => "OperatingSystem.FreeVirtualMemory",
            :labels => {},
            :value => mem[:AvailPageFile]
          },
          {
            :type => "gauge",
            :name => "windows_os_processes_limit",
            :desc => "OperatingSystem.MaxNumberOfProcesses",
            :labels => {},
            # prometheus-community/windows-exporter/collector/os.go#L275
            :value => 4294967295.0
          },
          {
            :type => "gauge",
            :name => "windows_os_process_memory_limit_bytes",
            :desc => "OperatingSystem.MaxProcessMemorySize",
            :labels => {},
            :value => mem[:TotalVirtual]
          },
          {
            :type => "gauge",
            :name => "windows_os_processes",
            :desc => "OperatingSystem.NumberOfProcesses",
            :labels => {},
            :value => perf[:ProcessCount]
          },
          {
            :type => "gauge",
            :name => "windows_os_users",
            :desc => "OperatingSystem.NumberOfUsers",
            :labels => {},
            :value => work[:LoggedOnUsers]
          },
          {
            :type => "gauge",
            :name => "windows_os_paging_limit_bytes",
            :desc => "OperatingSystem.SizeStoredInPagingFiles",
            :labels => {},
            :value => reg[:PagingLimitBytes]
          },
          {
            :type => "gauge",
            :name => "windows_os_virtual_memory_bytes",
            :desc => "OperatingSystem.TotalVirtualMemorySize",
            :labels => {},
            :value => mem[:TotalPageFile],
          },
          {
            :type => "gauge",
            :name => "windows_os_visible_memory_bytes",
            :desc => "OperatingSystem.TotalVisibleMemorySize",
            :labels => {},
            :value => mem[:TotalPhys]
          }
        ]
      end
    end
  end
end
