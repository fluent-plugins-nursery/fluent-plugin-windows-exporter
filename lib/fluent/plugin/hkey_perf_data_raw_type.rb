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
      # SYSTEMTIME :systemTime # TODO handle win32-SYSTEMTIME in ruby
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
end
