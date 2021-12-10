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

        @collectors = []
        #@collectors << method(:collect_cpu) if @cpu
        #@collectors << method(:collect_logical_disk) if @logical_disk
        #@collectors << method(:collect_memory) if @memory
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
              $log.warn(e.message)
            end
        end
        router.emit_stream(@tag, es)
      end

      def update_cache
        # Get system counters from WMI and HKEY_PERFORMANCE_DATA.
        # Save them to @cache.
      end

      def collect_time
         return [{
            :type => "counter",
            :name => "windows.time",
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

        return [
          {
            :type => "gauge",
            :name => "windows.os.info",
            :desc => "Windows version info",
            :labels => {
              :product => "Microsoft #{reg[:ProductName]}",
              :version => "#{work[:VersionMajor]}.#{work[:VersionMinor]}.#{reg[:CurrentBuildNumber]}"
            },
            :value => 1.0
          },
          {
            :type => "gauge",
            :name => "windows.os.timezone",
            :desc => "OperatingSystem.LocalDateTime",
            :labels => {:timezone => Time.now.zone},
            :value => mem[:AvailPhys]
          },
          {
            :type => "gauge",
            :name => "windows.os.time",
            :desc => "OperatingSystem.LocalDateTime",
            :labels => {},
            :value => Fluent::EventTime.now.to_f
          },
          {
            :type => "gauge",
            :name => "windows.os.paging_free_bytes",
            :desc => "OperatingSystem.FreeSpaceInPagingFiles",
            :labels => {},
            :value => 0  # TODO: Implement using HKEY_PERFORMANCE_DATA
          },
          {
            :type => "gauge",
            :name => "windows.os.virtual_memory_bytes",
            :desc => "OperatingSystem.TotalVirtualMemorySize",
            :labels => {},
            :value => mem[:AvailPageFile]
          },
          {
            :type => "gauge",
            :name => "windows.os.processes_limit",
            :desc => "OperatingSystem.MaxNumberOfProcesses",
            :labels => {},
            :value => 4294967295.0
          },
          {
            :type => "gauge",
            :name => "windows.os.processes_limit",
            :desc => "OperatingSystem.TotalVirtualMemorySize",
            :labels => {},
            :value => mem[:TotalVirtual]
          },
          {
            :type => "gauge",
            :name => "windows.os.processes",
            :desc => "OperatingSystem.NumberOfProcesses",
            :labels => {},
            :value => perf[:ProcessCount]
          },
          {
            :type => "gauge",
            :name => "windows.os.users",
            :desc => "OperatingSystem.NumberOfUsers",
            :labels => {},
            :value => work[:LoggedOnUsers]
          },
          {
            :type => "gauge",
            :name => "windows.os.paging_limit_bytes",
            :desc => "OperatingSystem.SizeStoredInPagingFiles",
            :labels => {},
            :value => reg[:PagingLimitBytes]
          },
          {
            :type => "gauge",
            :name => "windows.os.virtual_memory_bytes",
            :desc => "OperatingSystem.TotalVirtualMemorySize",
            :labels => {},
            :value => mem[:TotalPageFile],
          },
          {
            :type => "gauge",
            :name => "windows.os.visible_memory_bytes",
            :desc => "OperatingSystem.TotalVisibleMemorySize",
            :labels => {},
            :value => mem[:TotalPhys]
          }
        ]
      end
    end
  end
end
