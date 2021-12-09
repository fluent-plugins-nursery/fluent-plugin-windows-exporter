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

require 'fiddle/import'
require './hkey_perf_data_raw_type.rb'
require './hkey_perf_data_converted_type.rb'

module HKeyPerfDataReader
  class Reader
    def read
      raw_data = RawReader.new.read
      puts("header=#{raw_data[0..7]}") # for debug
      puts("#{raw_data[0..30].chars.map { |c| c.unpack("H*")[0] }}") # for debug

      endian = little_endian?(raw_data) ? :little : :big
      puts("endian=#{endian}") # for debug

      header = read_header(raw_data, endian)
      puts("signature=#{header.signature}") # for debug
      puts("headerLength=#{header.headerLength}") # for debug
      puts("numObjectTypes=#{header.numObjectTypes}") # for debug

      unless header.signature == "PERF"
        p "Invalid performance block header"
        return nil
      end

      header

      # TODO read each performance block and return
    end

    private

    def little_endian?(raw_data)
      return raw_data[8..11].unpack("I*")[0] == 1
    end

    def read_header(raw_data, endian)
      raw_perf_data_block = RawType::PerfDataBlock.new(:endian => endian).read(raw_data)
      ConvertedType::PerfDataBlock.new(raw_perf_data_block)
    end
  end

  class RawReader
    def read
      type = packdw(0)
      size = packdw(128*1024*1024) # 128kb (for now)
      data = "\0".force_encoding('ASCII-8BIT') * unpackdw(size)
      ret = API::RegQueryValueExW.call(Constants::HKEY_PERFORMANCE_DATA, "Global", 0, type, data, size)
      data
    end

    private

    module Constants
      HKEY_PERFORMANCE_DATA = 0x80000004
    end

    module API
      include Constants
      extend Fiddle::Importer
      dlload "advapi32.dll"
      [
        "long RegQueryValueExW(void *, void *, void *, void *, void *, void *)",
      ].each do |fn|
        cfunc = extern fn, :stdcall
        const_set cfunc.name.intern, cfunc
      end
    end

    def packdw(dw)
      [dw].pack('V')
    end
    
    def unpackdw(dw)
      dw += [0].pack('V')
      dw.unpack('V')[0]
    end
  end
end
