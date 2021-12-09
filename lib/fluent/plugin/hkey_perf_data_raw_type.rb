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

require 'bindata'

module HKeyPerfDataReader
  module RawType
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
  end
end
