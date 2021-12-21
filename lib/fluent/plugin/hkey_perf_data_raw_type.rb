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

require "bindata"

module HKeyPerfDataReader
  module RawType
    # https://docs.microsoft.com/en-us/windows/win32/api/winperf/ns-winperf-perf_data_block
    class PerfDataBlock < BinData::Record
      endian :big_and_little
      array :signature, :type => :uint16, :initial_length => 4
      uint32 :littleEndian
      uint32 :version
      uint32 :revision
      uint32 :totalByteLength
      uint32 :headerLength
      uint32 :numObjectTypes
      int32 :defaultObject
      # If the following values are needed, we have to handle win32-SYSTEMTIME in ruby.
      # SYSTEMTIME :systemTime
      # int64 :perfTime
      # int64 :perfFreq
      # int64 :perfTime100nSec
      # uint32 :systemNameLength
      # uint32 :systemNameOffset
    end

    # https://docs.microsoft.com/en-us/windows/win32/api/winperf/ns-winperf-perf_object_type
    class PerfObjectType < BinData::Record
      endian :big_and_little
      uint32 :totalByteLength
      uint32 :definitionLength
      uint32 :headerLength
      uint32 :objectNameTitleIndex
      uint32 :objectNameTitle
      uint32 :objectHelpTitleIndex
      uint32 :objectHelpTitle
      uint32 :detailLevel
      uint32 :numCounters
      int32 :defaultCounter
      int32 :numInstances
      uint32 :codePage
      int64 :perfTime
      int64 :perfFreq
    end

    # https://docs.microsoft.com/en-us/windows/win32/api/winperf/ns-winperf-perf_counter_definition
    class PerfCounterDefinition < BinData::Record
      endian :big_and_little
      uint32 :byteLength
      uint32 :counterNameTitleIndex
      uint32 :counterNameTitle
      uint32 :counterHelpTitleIndex
      uint32 :counterHelpTitle
      int32 :defaultScale
      uint32 :detailLevel
      uint32 :counterType
      uint32 :counterSize
      uint32 :counterOffset
    end

    # https://docs.microsoft.com/en-us/windows/win32/api/winperf/ns-winperf-perf_counter_block
    class PerfCounterBlock < BinData::Record
      endian :big_and_little
      uint32 :byteLength
    end

    # https://docs.microsoft.com/en-us/windows/win32/api/winperf/ns-winperf-perf_instance_definition
    class PerfInstanceDefinition < BinData::Record
      endian :big_and_little
      uint32 :byteLength
      uint32 :parentObjectTitleIndex
      uint32 :parentObjectInstance
      uint32 :uniqueID
      uint32 :nameOffset
      uint32 :nameLength
    end
  end

  class BinaryParser
    include RawType

    def initialize(is_little_endian: true)
      @is_little_endian = is_little_endian

      # In order to speed up the parsing, initialize each bindata first.
      # https://github.com/dmendel/bindata/wiki/FAQ#how-do-i-speed-up-initialization
      @data_block = PerfDataBlock.new(:endian => endian)
      @object_type = PerfObjectType.new(:endian => endian)
      @counter_definition = PerfCounterDefinition.new(:endian => endian)
      @counter_block = PerfCounterBlock.new(:endian => endian)
      @instance_definition = PerfInstanceDefinition.new(:endian => endian)
    end

    def parse_data_block(data)
      result = @data_block.read(data).snapshot
      @data_block.clear
      result
    end

    def parse_object_type(data)
      result = @object_type.read(data).snapshot
      @object_type.clear
      result
    end

    def parse_counter_definition(data)
      result = @counter_definition.read(data).snapshot
      @counter_definition.clear
      result
    end

    def parse_counter_block(data)
      result = @counter_block.read(data).snapshot
      @counter_block.clear
      result
    end

    def parse_instance_definition(data)
      result = @instance_definition.read(data).snapshot
      @instance_definition.clear
      result
    end

    private

    def endian
      @is_little_endian ? :little : :big
    end
  end
end
