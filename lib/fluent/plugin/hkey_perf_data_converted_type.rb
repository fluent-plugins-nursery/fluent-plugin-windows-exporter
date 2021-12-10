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

require "./hkey_perf_data_raw_type.rb"

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
    attr_reader :counters

    def initialize(name)
      @name = name
      @counters = {}
    end

    def add_counter(perf_counter)
      @counters[perf_counter.name] = perf_counter
    end
  end

  class PerfCounter
    attr_reader :name
    attr_accessor :value

    def initialize(name)
      @name = name
      @value = nil
    end
  end
end
