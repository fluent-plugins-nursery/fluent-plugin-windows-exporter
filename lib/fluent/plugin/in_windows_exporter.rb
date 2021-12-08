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

module Fluent
  module Plugin
    class WindowsExporterInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("windows_exporter", self)

      helpers :timer

      desc "Tag of the output events"
      config_param :tag, :string, default: nil
      desc "The interval time between data collection"
      config_param :interval, :time, default: 5
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
        #@collectors << method(:collect_os) if @os
      end

      def start
        super
        timer_execute(:in_windows_exporter, @interval, &method(:on_timer))
      end

      def on_timer
        now = Fluent::EventTime.now
        update_cache()
        for method in @collectors do
            router.emit(@tag, now, method.call())
        end
      end

      def update_cache
        # Get system counters from WMI and HKEY_PERFORMANCE_DATA.
        # Save them to @cache.
      end

      def collect_time
         return {
            :type => "counter",
            :labels => {},
            :desc =>  "System time in seconds since epoch (1970)",
            :timestamp => Fluent::EventTime.now.to_f,
            :value => Fluent::EventTime.now.to_f
        }
      end

      def shutdown
      end
    end
  end
end
