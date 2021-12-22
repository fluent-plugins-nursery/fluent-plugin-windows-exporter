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
    module Constants
      # https://github.com/prometheus-community/windows_exporter/blob/master/collector/collector.go
      TICKS_TO_SECONDS_SCALE_FACTOR = 1 / 1e7
      WINDOWS_EPOCH = 116444736000000000

      # https://github.com/leoluk/perflib_exporter/blob/master/collector/mapper.go
      # These flag values may be composed of the base flags in winperf.h.
      # ref: https://github.com/Kochise/Picat-win32/blob/master/emu/windows/winperf.h
      PERF_ELAPSED_TIME = 0x30240500
      PERF_100NSEC_TIMER = 0x20510500
      PERF_PRECISION_100NS_TIMER = 0x20570500
    end

    class WindowsExporterInput < Fluent::Plugin::Input
      include Constants

      Fluent::Plugin.register_input("windows_exporter", self)

      helpers :timer

      desc "Tag of the output events"
      config_param :tag, :string, default: "windows.metrics"
      desc "The interval time between data collection"
      config_param :scrape_interval, :time, default: 60
      desc "Enable cpu collector"
      config_param :cpu, :bool, default: true
      desc "Enable disk collector"
      config_param :logical_disk, :bool, default: true
      desc "Enable memory collector"
      config_param :memory, :bool, default: true
      desc "Enable network collector"
      config_param :net, :bool, default: true
      desc "Enable OS collector"
      config_param :os, :bool, default: true

      def configure(conf)
        super
        @cache_manager = CacheManager.new

        @collectors = []
        @collectors << method(:collect_cpu) if @cpu
        @collectors << method(:collect_logical_disk) if @logical_disk
        @collectors << method(:collect_memory) if @memory
        @collectors << method(:collect_net) if @net
        @collectors << method(:collect_os) if @os
      end

      def start
        super
        timer_execute(:in_windows_exporter, @scrape_interval, &method(:on_timer))
        $log.info("Start in_windows_exporter (%i collectors, every %is)" % [@collectors.count, @scrape_interval])
      end

      def shutdown
        super
      end

      def on_timer
        now = Fluent::EventTime.now
        update_cache()
        $log.debug("Updated Windows counters (%.2fs)" % (Fluent::EventTime.now.to_f - now.to_f))

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
        @cache_manager.update
      end

      def collect_cpu
        hpd = @cache_manager.hkey_perf_data_cache
        counterset_name = "Processor Information"
        unless hpd.key?(counterset_name)
          $log.warn("Could not get HKeyPerfData CounterSet: #{counterset_name}")
          return []
        end

        records = []
        for core in hpd[counterset_name].instances do
          if core.name.downcase.include?("_total")
            next
          end
          records += [
            {
              "type" => "counter",
              "name" => "windows_cpu_cstate_seconds_total",
              "desc" => "Time spent in low-power idle state",
              "labels" => {"core" => core.name, "state" => "c1" },
              "value" => core.counters["% C1 Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_cstate_seconds_total",
              "desc" => "Time spent in low-power idle state",
              "labels" => {"core" => core.name, "state" => "c2" },
              "value" => core.counters["% C2 Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_cstate_seconds_total",
              "desc" => "Time spent in low-power idle state",
              "labels" => {"core" => core.name, "state" => "c3" },
              "value" => core.counters["% C3 Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_time_total",
              "desc" => "Time that processor spent in different modes (idle, user, system, ...)",
              "labels" => {"core" => core.name, "mode" => "idle"},
              "value" => core.counters["% Idle Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_time_total",
              "desc" => "Time that processor spent in different modes (idle, user, system, ...)",
              "labels" => {"core" => core.name, "mode" => "interrupt"},
              "value" => core.counters["% Interrupt Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_time_total",
              "desc" => "Time that processor spent in different modes (idle, user, system, ...)",
              "labels" => {"core" => core.name, "mode" => "dpc"},
              "value" => core.counters["% DPC Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_time_total",
              "desc" => "Time that processor spent in different modes (idle, user, system, ...)",
              "labels" => {"core" => core.name, "mode" => "privileged"},
              "value" => core.counters["% Privileged Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_time_total",
              "desc" => "Time that processor spent in different modes (idle, user, system, ...)",
              "labels" => {"core" => core.name, "mode" => "user"},
              "value" => core.counters["% User Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_interrupts_total",
              "desc" => "Total number of received and serviced hardware interrupts",
              "labels" => {"core" => core.name},
              "value" => core.counters["Interrupts/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_dpcs_total",
              "desc" => "Total number of received and serviced deferred procedure calls (DPCs)",
              "labels" => {"core" => core.name},
              "value" => core.counters["DPCs Queued/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_clock_interrupts_total",
              "desc" => "Total number of received and serviced clock tick interrupts",
              "labels" => {"core" => core.name},
              "value" => core.counters["Clock Interrupts/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_cpu_idle_break_events_total",
              "desc" => "Total number of time processor was woken from idle",
              "labels" => {"core" => core.name},
              "value" => core.counters["Idle Break Events/sec"].value
            },
            {
              "type" => "gauge",
              "name" => "windows_cpu_parking_status",
              "desc" => "Parking Status represents whether a processor is parked or not",
              "labels" => {"core" => core.name},
              "value" => core.counters["Parking Status"].value
            },
            {
              "type" => "gauge",
              "name" => "windows_cpu_core_frequency_mhz",
              "desc" => "Core frequency in megahertz",
              "labels" => {"core" => core.name},
              "value" => core.counters["Processor Frequency"].value
            },
            {
              "type" => "gauge",
              "name" => "windows_cpu_processor_performance",
              "desc" => "Processor Performance is the average performance of the processor while it is executing instructions, as a percentage of the nominal performance of the processor. On some processors, Processor Performance may exceed 100%",
              "labels" => {"core" => core.name},
              "value" => core.counters["% Processor Performance"].value
            }
          ]
        end
        return records
      end

      def collect_logical_disk
        hpd = @cache_manager.hkey_perf_data_cache
        counterset_name = "LogicalDisk"
        unless hpd.key?(counterset_name)
          $log.warn("Could not get HKeyPerfData CounterSet: #{counterset_name}")
          return []
        end

        records = []
        for volume in hpd[counterset_name].instances do
          if volume.name.downcase.include?("_total")
            next
          end

          records += [
            {
              "type" => "gauge",
              "name" => "windows_logical_disk_requests_queued",
              "desc" => "Number of requests outstanding on the disk at the time the performance data is collected",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Current Disk Queue Length"].value
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_read_bytes_total",
              "desc" => "Rate at which bytes are transferred from the disk during read operations",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Disk Read Bytes/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_reads_total",
              "desc" => "Rate of read operations on the disk",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Disk Reads/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_write_bytes_total",
              "desc" => "Rate at which bytes are transferred to the disk during write operations",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Disk Write Bytes/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_writes_total",
              "desc" => "Rate of write operations on the disk",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Disk Writes/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_read_seconds_total",
              "desc" => "Seconds the disk was busy servicing read requests",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["% Disk Read Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_write_seconds_total",
              "desc" => "Seconds the disk was busy servicing write requests",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["% Disk Write Time"].value
            },
            {
              "type" => "gauge",
              "name" => "windows_logical_disk_free_bytes",
              "desc" => "Unused space of the disk in bytes (not real time, updates every 10-15 min)",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Free Megabytes"].value * 1024 * 1024
            },
            {
              "type" => "gauge",
              "name" => "windows_logical_disk_size_bytes",
              "desc" => "Total size of the disk in bytes (not real time, updates every 10-15 min)",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["% Free Space"].base_value * 1024 * 1024
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_idle_seconds_total",
              "desc" => "Seconds the disk was idle (not servicing read/write requests)",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["% Idle Time"].value
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_split_ios_total",
              "desc" => "Number of I/Os to the disk split into multiple I/Os",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Split IO/Sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_read_latency_seconds_total",
              "desc" => "Shows the average time, in seconds, of a read operation from the disk",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Avg. Disk sec/Read"].value * TICKS_TO_SECONDS_SCALE_FACTOR
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_write_latency_seconds_total",
              "desc" => "Shows the average time, in seconds, of a write operation to the disk",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Avg. Disk sec/Write"].value * TICKS_TO_SECONDS_SCALE_FACTOR
            },
            {
              "type" => "counter",
              "name" => "windows_logical_disk_read_write_latency_seconds_total",
              "desc" => "Shows the time, in seconds, of the average disk transfer",
              "labels" => {"volume" => volume.name},
              "value" => volume.counters["Avg. Disk sec/Transfer"].value * TICKS_TO_SECONDS_SCALE_FACTOR
            }
          ]
        end
        return records
      end

      def collect_memory
        hpd = @cache_manager.hkey_perf_data_cache
        counterset_name = "Memory"
        unless hpd.key?(counterset_name)
          $log.warn("Could not get HKeyPerfData CounterSet: #{counterset_name}")
          return []
        end

        return [
          {
            "type" => "gauge",
            "name" => "windows_memory_available_bytes",
            "desc" => "The amount of physical memory immediately available for allocation to a process or for system use. It is equal to the sum of memory assigned to the standby (cached), free and zero page lists",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Available Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_cache_bytes",
            "desc" => "Number of bytes currently being used by the file system cache",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Cache Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_cache_bytes_peak",
            "desc" => "Maximum number of CacheBytes after the system was last restarted",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Cache Bytes Peak"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_cache_faults_total",
            "desc" => "Number of faults which occur when a page sought in the file system cache is not found there and must be retrieved from elsewhere in memory (soft fault) or from disk (hard fault)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Cache Faults/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_commit_limit",
            "desc" => "Amount of virtual memory, in bytes, that can be committed without having to extend the paging file(s)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Commit Limit"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_committed_bytes",
            "desc" => "Amount of committed virtual memory, in bytes",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Committed Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_demand_zero_faults_total",
            "desc" => "The number of zeroed pages required to satisfy faults. Zeroed pages, pages emptied of previously stored data and filled with zeros, are a security feature of Windows that prevent processes from seeing data stored by earlier processes that used the memory space",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Demand Zero Faults/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_free_and_zero_page_list_bytes",
            "desc" => "(FreeAndZeroPageListBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Free & Zero Page List Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_free_system_page_table_entries",
            "desc" => "Number of page table entries not being used by the system",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Free System Page Table Entries"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_modified_page_list_bytes",
            "desc" => "(ModifiedPageListBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Modified Page List Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_page_faults_total",
            "desc" => "Overall rate at which faulted pages are handled by the processor",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Page Faults/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_swap_page_reads_total",
            "desc" => "Number of disk page reads (a single read operation reading several pages is still only counted once)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Page Reads/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_swap_pages_read_total",
            "desc" => "Number of pages read across all page reads (ie counting all pages read even if they are read in a single operation)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Pages Input/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_swap_pages_written_total",
            "desc" => "Number of pages written across all page writes (ie counting all pages written even if they are written in a single operation)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Pages Output/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_swap_page_operations_total",
            "desc" => "Total number of swap page read and writes (PagesPersec)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Pages/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_swap_page_writes_total",
            "desc" => "Number of disk page writes (a single write operation writing several pages is still only counted once)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Page Writes/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_pool_nonpaged_allocs_total",
            "desc" => "The number of calls to allocate space in the nonpaged pool. The nonpaged pool is an area of system memory area for objects that cannot be written to disk, and must remain in physical memory as long as they are allocated",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Pool Nonpaged Allocs"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_pool_nonpaged_bytes_total",
            "desc" => "Number of bytes in the non-paged pool",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Pool Nonpaged Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_pool_paged_allocs_total",
            "desc" => "Number of calls to allocate space in the paged pool, regardless of the amount of space allocated in each call",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Pool Paged Allocs"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_pool_paged_bytes",
            "desc" => "Number of bytes in the paged pool",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Pool Paged Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_pool_paged_resident_bytes",
            "desc" => "(PoolPagedResidentBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Pool Paged Resident Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_standby_cache_core_bytes",
            "desc" => "(StandbyCacheCoreBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Standby Cache Core Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_standby_cache_normal_priority_bytes",
            "desc" => "(StandbyCacheNormalPriorityBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Standby Cache Normal Priority Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_standby_cache_reserve_bytes",
            "desc" => "(StandbyCacheReserveBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Standby Cache Reserve Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_system_cache_resident_bytes",
            "desc" => "(SystemCacheResidentBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["System Cache Resident Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_system_code_resident_bytes",
            "desc" => "(SystemCodeResidentBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["System Code Resident Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_system_code_total_bytes",
            "desc" => "(SystemCodeTotalBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["System Code Total Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_system_driver_resident_bytes",
            "desc" => "(SystemDriverResidentBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["System Driver Resident Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_system_driver_total_bytes",
            "desc" => "(SystemDriverTotalBytes)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["System Driver Total Bytes"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_transition_faults_total",
            "desc" => "(TransitionFaultsPersec)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Transition Faults/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_transition_pages_repurposed_total",
            "desc" => "(TransitionPagesRePurposedPersec)",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Transition Pages RePurposed/sec"].value
          },
          {
            "type" => "gauge",
            "name" => "windows_memory_write_copies_total",
            "desc" => "The number of page faults caused by attempting to write that were satisfied by copying the page from elsewhere in physical memory",
            "labels" => {},
            "value" => hpd["Memory"].instances[0].counters["Write Copies/sec"].value
          }
        ]
      end

      def collect_net
        hpd = @cache_manager.hkey_perf_data_cache
        counterset_name = "Network Interface"
        unless hpd.key?(counterset_name)
          $log.warn("Could not get HKeyPerfData CounterSet: #{counterset_name}")
          return []
        end

        records = []
        for nic in hpd[counterset_name].instances do
          name = nic.name.gsub!(/[^a-zA-Z0-9]/, '_')
          if name == ""
            next
          end

          records += [
            {
              "type" => "counter",
              "name" => "windows_net_bytes_received_total",
              "desc" => "Total bytes received by interface",
              "labels" => {"nic": name},
              "value" => nic.counters["Bytes Received/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_bytes_sent_total",
              "desc" => "Total bytes transmitted by interface",
              "labels" => {"nic": name},
              "value" => nic.counters["Bytes Sent/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_bytes_total",
              "desc" => "Total bytes received and transmitted by interface",
              "labels" => {"nic": name},
              "value" => nic.counters["Bytes Total/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_packets_outbound_discarded_total",
              "desc" => "Total outbound packets that were chosen to be discarded even though no errors had been detected to prevent transmission",
              "labels" => {"nic": name},
              "value" => nic.counters["Packets Outbound Discarded"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_packets_outbound_errors_total",
              "desc" => "Total packets that could not be transmitted due to errors",
              "labels" => {"nic": name},
              "value" => nic.counters["Packets Outbound Errors"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_packets_total",
              "desc" => "Total packets received and transmitted by interface",
              "labels" => {"nic": name},
              "value" => nic.counters["Packets/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_packets_received_discarded_total",
              "desc" => "Total inbound packets that were chosen to be discarded even though no errors had been detected to prevent delivery",
              "labels" => {"nic": name},
              "value" => nic.counters["Packets Received Discarded"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_packets_received_errors_total",
              "desc" => "Total packets that could not be received due to errors",
              "labels" => {"nic": name},
              "value" => nic.counters["Packets Received Errors"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_packets_received_total",
              "desc" => "Total packets received by interface",
              "labels" => {"nic": name},
              "value" => nic.counters["Packets Received/sec"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_packets_received_unknown_total",
              "desc" => "Total packets received by interface that were discarded because of an unknown or unsupported protocol",
              "labels" => {"nic": name},
              "value" => nic.counters["Packets Received Unknown"].value
            },
            {
              "type" => "counter",
              "name" => "windows_net_packets_sent_total",
              "desc" => "Total packets transmitted by interface",
              "labels" => {"nic": name},
              "value" => nic.counters["Packets Sent/sec"].value
            },
            {
              "type" => "gauge",
              "name" => "windows_net_current_bandwidth_bytes",
              "desc" => "Estimate of the interface's current bandwidth in bytes per second",
              "labels" => {"nic": name},
              "value" => nic.counters["Current Bandwidth"].value / 8
            }
          ]
        end
        return records
      end

      def collect_os
        hpd = @cache_manager.hkey_perf_data_cache
        mem = @cache_manager.memory_status_cache
        work = @cache_manager.work_station_info_cache
        perf = @cache_manager.performance_info_cache
        reg = @cache_manager.registry_info_cache

        records = [
          {
            "type" => "gauge",
            "name" => "windows_os_info",
            "desc" => "Contains full product name & version in labels",
            "labels" => {
              :product => "Microsoft #{reg[:ProductName]}",
              :version => "#{work[:VersionMajor]}.#{work[:VersionMinor]}.#{reg[:CurrentBuildNumber]}"
            },
            "value" => 1.0
          },
          {
            "type" => "gauge",
            "name" => "windows_os_physical_memory_free_bytes",
            "desc" => "Bytes of physical memory currently unused and available",
            "labels" => {},
            "value" => mem[:AvailPhys]
          },
          {
            "type" => "gauge",
            "name" => "windows_os_time",
            "desc" => "Current time as reported by the operating system, in Unix time",
            "labels" => {},
            "value" => Fluent::EventTime.now.to_f
          },
          {
            "type" => "gauge",
            "name" => "windows_os_timezone",
            "desc" => "Current timezone as reported by the operating system",
            "labels" => {:timezone => Time.now.strftime("%z")},
            "value" => 1.0
          },
          {
            "type" => "gauge",
            "name" => "windows_os_virtual_memory_free_bytes",
            "desc" => "Bytes of virtual memory currently unused and available",
            "labels" => {},
            "value" => mem[:AvailPageFile]
          },
          {
            "type" => "gauge",
            "name" => "windows_os_processes_limit",
            "desc" => "Maximum number of process contexts the operating system can support. The default value set by the provider is 4294967295 (0xFFFFFFFF)",
            "labels" => {},
            # prometheus-community/windows-exporter/collector/os.go#L275
            "value" => 4294967295.0
          },
          {
            "type" => "gauge",
            "name" => "windows_os_process_memory_limit_bytes",
            "desc" => "Maximum number of bytes of memory that can be allocated to a process",
            "labels" => {},
            "value" => mem[:TotalVirtual]
          },
          {
            "type" => "gauge",
            "name" => "windows_os_processes",
            "desc" => "Number of process contexts currently loaded or running on the operating system",
            "labels" => {},
            "value" => perf[:ProcessCount]
          },
          {
            "type" => "gauge",
            "name" => "windows_os_users",
            "desc" => "Number of user sessions for which the operating system is storing state information currently. For a list of current active logon sessions.",
            "labels" => {},
            "value" => work[:LoggedOnUsers]
          },
          {
            "type" => "gauge",
            "name" => "windows_os_paging_limit_bytes",
            "desc" => "Total number of bytes that can be sotred in the operating system paging files. 0 (zero) indicates that there are no paging files",
            "labels" => {},
            "value" => reg[:PagingLimitBytes]
          },
          {
            "type" => "gauge",
            "name" => "windows_os_virtual_memory_bytes",
            "desc" => "Bytes of virtual memory",
            "labels" => {},
            "value" => mem[:TotalPageFile],
          },
          {
            "type" => "gauge",
            "name" => "windows_os_visible_memory_bytes",
            "desc" => "Total bytes of physical memory available to the operating system. This value does not necessarily indicate the true amount of physical memory, but what is reported to the operating system as available to it",
            "labels" => {},
            "value" => mem[:TotalPhys]
          }
        ]

        counterset_name = "Paging File"
        unless hpd.key?(counterset_name)
          $log.warn("Could not get HKeyPerfData CounterSet: #{counterset_name}")
          return records
        end

        pfusage = 0
        for ins in hpd[counterset_name].instances do
          unless ins.name.downcase.include?("_total")
            pfusage += ins.counters["% Usage"].value
          end
        end

        records += [
          {
            "type" => "gauge",
            "name" => "windows_os_paging_free_bytes",
            "desc" => "Number of bytes that can be mapped into the operating system paging files without causing any other pages to be swapped out",
            "labels" => {},
            "value" =>  reg[:PagingLimitBytes] - pfusage * perf[:PageSize]
          }
        ]

        return records
      end
    end

    module HKeyPerfDataWhiteList
      NAMES = [
        "Processor Information",
        "LogicalDisk",
        "Memory",
        "Network Interface",
        "Paging File",
      ]
    end

    class CacheManager
      include Constants

      attr_reader :hkey_perf_data_cache
      attr_reader :memory_status_cache
      attr_reader :work_station_info_cache
      attr_reader :performance_info_cache
      attr_reader :registry_info_cache

      def initialize
        @hkey_perf_data_reader = HKeyPerfDataReader::Reader.new(
          object_name_whitelist: HKeyPerfDataWhiteList::NAMES,
          logger: $log
        )

        @hkey_perf_data_cache = nil
        @memory_status_cache = nil
        @work_station_info_cache = nil
        @performance_info_cache = nil
        @registry_info_cache = nil
      end

      def update
        @hkey_perf_data_cache = get_hkey_perf_data()
        @memory_status_cache = WinFFI.GetMemoryStatus()
        @work_station_info_cache = WinFFI.GetWorkstationInfo()
        @performance_info_cache = WinFFI.GetPerformanceInfo()
        @registry_info_cache = WinFFI.GetRegistryInfo()
      end

      private

      def get_hkey_perf_data
        data = @hkey_perf_data_reader.read

        data.each do |object_name, object|
          object.instances.each do |instance|
            instance.counters.each do |counter_name, counter|
              counter.value = calc_hpd_counter_value(
                object, counter.type, counter.value
              )
            end
          end
        end

        data
      end

      def calc_hpd_counter_value(object, type, value)
        # https://github.com/prometheus-community/windows_exporter/blob/master/collector/perflib.go

        case type
        when PERF_ELAPSED_TIME
          return (value - WINDOWS_EPOCH) / object.perf_freq
        when PERF_100NSEC_TIMER, PERF_PRECISION_100NS_TIMER
          return value * TICKS_TO_SECONDS_SCALE_FACTOR
        else
          return value
        end
      end
    end
  end
end
