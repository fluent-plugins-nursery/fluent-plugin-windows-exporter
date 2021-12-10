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

require "fiddle/import"
require_relative "hkey_perf_data_raw_type"
require_relative "hkey_perf_data_converted_type"

# A reader for Windows registry key: HKeyPerfData.
# This provides Windows performance counter data.
#   ref: https://docs.microsoft.com/en-us/windows/win32/perfctrs/using-the-registry-functions-to-consume-counter-data
# You can use this as follows:
#
# Usage:
#   require_relative "hkey_perf_data_reader"
#   reader = HKeyPerfDataReader::Reader.new
#   data = reader.read
#   data["Memory"].counters
#     => {:Page Faults/sec=>1097060125, :Available Bytes=>6256005120,  ... }

module HKeyPerfDataReader
  module Constants
    HKEY_PERFORMANCE_DATA = 0x80000004
    PERF_NO_INSTANCES = -1
  end

  class Reader
    include Constants

    def initialize(for_debug = false)
      @raw_data = nil
      @is_little_endian = true
      @counter_name_reader = CounterNameTableReader.new
      @for_debug = for_debug
    end

    def read
      @raw_data = RawReader.read
      @is_little_endian = @raw_data[8..11].unpack("L")[0] == 1

      print_debug("endian=#{endian}")

      header = read_header
      print_debug("numObjectTypes=#{header.numObjectTypes}")

      unless header.signature == "PERF"
        puts("Invalid performance block header")
        return nil
      end

      perf_objects = {}

      offset = header.headerLength
      header.numObjectTypes.times do
        begin
          perf_object, total_byte_length = read_perf_object(offset)

          print_debug_perf_object(perf_object)

          perf_objects[perf_object.name] = perf_object
          offset += total_byte_length
        rescue => e
          puts("error occurred: #{e.message}")
        end
      end

      perf_objects
    end

    private

    def print_debug(str)
      return unless @for_debug
      puts str
    end

    def print_debug_perf_object(perf_object)
      print_debug("object name: #{perf_object.name}")
      print_debug("counters: #{perf_object.counters}")
      print_debug("")
    end

    def endian
      @is_little_endian ? :little : :big
    end

    def read_header
      raw_perf_data_block = RawType::PerfDataBlock.new(:endian => endian)
        .read(@raw_data).snapshot
      ConvertedType::PerfDataBlock.new(raw_perf_data_block)
    end

    def read_perf_object(start_offset)
      cur_offset = start_offset

      object_type = RawType::PerfObjectType.new(:endian => endian)
        .read(@raw_data[cur_offset..]).snapshot
      unless object_type.numInstances == PERF_NO_INSTANCES
        # TODO handle multi instance
        print_debug("numInstances: #{object_type.numInstances}")
      end
      cur_offset += object_type.headerLength

      perf_object = ConvertedType::PerfObject.new(
        @counter_name_reader.read(object_type.objectNameTitleIndex)
      )

      object_type.numCounters.times do
        counter_def = RawType::PerfCounterDefinition.new(:endian => endian)
          .read(@raw_data[cur_offset..]).snapshot

        counter_name = @counter_name_reader.read(counter_def.counterNameTitleIndex)
        counter_value = read_counter_value(
          counter_def,
          start_offset + object_type.definitionLength + counter_def.counterOffset,
        )

        perf_object.add_counter(counter_name, counter_value)
        cur_offset += counter_def.byteLength
      end

      return perf_object, object_type.totalByteLength
    end

    def read_counter_value(counter_def, offset)
      # Currently counter data is limited to DWORD and ULONGLONG data types
      #   ref: https://docs.microsoft.com/en-us/windows/win32/perfctrs/retrieving-counter-data
      # We don't need to consider `counterType` unless we need to format the value for output.
      endian_mark = @is_little_endian ? "<" : ">"
      case counter_def.counterSize
      when 4
        return @raw_data[offset..offset+3].unpack("L#{endian_mark}")[0]
      when 8
        return @raw_data[offset..offset+7].unpack("Q#{endian_mark}")[0]
      else
        return @raw_data[offset..offset+3].unpack("L#{endian_mark}")[0]
      end
    end
  end

  class CounterNameTableReader
    def initialize
      @counter_name_table = CounterNameTableReader.build_table
    end

    def read(index)
      @counter_name_table[index]
    end

    private

    def self.build_table
      # https://docs.microsoft.com/en-us/windows/win32/perfctrs/retrieving-counter-names-and-help-text
      # https://github.com/leoluk/perflib_exporter

      table = {}

      raw_data = RawReader.read_counter_name_table
      # TODO Does the endian need to be linked to the one of PerfDataBlock? Or is it OK to use only little endian?
      converted_data = raw_data.encode("UTF-8", "UTF-16LE").split("\u0000")

      loop do
        index = converted_data.shift
        value = converted_data.shift
        break if index.nil? || value.nil?
        table[index.to_i] = value
      end

      table
    end
  end

  module API
    include Constants
    extend Fiddle::Importer
    dlload "advapi32.dll"
    [
      "long RegQueryValueExW(void *, void *, void *, void *, void *, void *)",
      "long RegCloseKey(void *)",
    ].each do |fn|
      cfunc = extern fn, :stdcall
      const_set cfunc.name.intern, cfunc
    end
  end

  module RawReader
    def self.read
      type = packdw(0)
      size = packdw(128*1024*1024) # 128kb (for now)
      data = "\0".force_encoding("ASCII-8BIT") * unpackdw(size)
      ret = API::RegQueryValueExW.call(Constants::HKEY_PERFORMANCE_DATA, make_wstr("Global"), 0, type, data, size)
      puts("RegQueryValueExW : ret=#{ret}") # for debug

      # https://docs.microsoft.com/en-us/windows/win32/perfctrs/using-the-registry-functions-to-consume-counter-data
      # TODO The document above says we must call `RegCloseKey`, but this returns error code: 6 (ERROR_INVALID_HANDLE)
      ret = API::RegCloseKey.call(Constants::HKEY_PERFORMANCE_DATA)
      puts("RegCloseKey : ret=#{ret}") # for debug

      data
    end

    def self.read_counter_name_table
      # https://docs.microsoft.com/en-us/windows/win32/perfctrs/retrieving-counter-names-and-help-text
      type = packdw(0)
      size = packdw(128*1024*1024) # 128kb (for now)
      data = "\0".force_encoding("ASCII-8BIT") * unpackdw(size)
      ret = API::RegQueryValueExW.call(Constants::HKEY_PERFORMANCE_DATA, make_wstr("Counter 009"), 0, type, data, size)
      puts("RegQueryValueExW : ret=#{ret}") # for debug

      data
    end

    private

    def self.packdw(dw)
      [dw].pack("V")
    end
    
    def self.unpackdw(dw)
      dw += [0].pack("V")
      dw.unpack("V")[0]
    end

    def self.make_wstr(str)
      str.encode(Encoding::UTF_16LE)
    end
  end
end
