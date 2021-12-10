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

require_relative "hkey_perf_data_raw_type.rb"

module HKeyPerfDataReader::ConvertedType
  class PerfDataBlock
    attr_reader :signature
    attr_reader :version
    attr_reader :revision
    attr_reader :totalByteLength
    attr_reader :headerLength
    attr_reader :numObjectTypes

    def initialize(raw_perf_data_block)
      @signature = raw_perf_data_block.signature.pack("c*")
      @version = raw_perf_data_block.version
      @revision = raw_perf_data_block.revision
      @totalByteLength = raw_perf_data_block.totalByteLength
      @headerLength = raw_perf_data_block.headerLength
      @numObjectTypes = raw_perf_data_block.numObjectTypes
    end
  end

  class PerfObject
    attr_reader :name
    attr_reader :instances
    attr_reader :counter_defs

    def initialize(name)
      @name = name
      @instances = []
      @counter_defs = []
    end

    def instance_names
      @instances.map { |i| i.name }
    end

    def add_counter_def(counter_def)
      @counter_defs.append(counter_def)
    end

    def add_instance(perf_instance)
      @instances.append(perf_instance)
    end
  end

  class PerfCounterDef
    attr_reader :name
    attr_reader :counter_offset
    attr_reader :counter_size

    def initialize(name, raw_counter_def)
      @name = name
      @counter_offset = raw_counter_def.counterOffset
      @counter_size = raw_counter_def.counterSize
    end
  end

  class PerfInstance
    attr_reader :name
    attr_reader :counters

    def initialize(name)
      @name = name
      @counters = {}
    end

    def add_counter(name, value)
      @counters[name] = value
    end
  end
end
