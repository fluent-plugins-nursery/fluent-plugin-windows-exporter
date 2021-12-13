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
#   data.keys
#     => ["RAS", "WSMan Quota Statistics", "Event Log", ...]
#   data["Memory"].instances[0].counters
#     => {"Page Faults/sec"=>1097060125, "Available Bytes"=>6256005120,  ...}
#   data["Processor"].instance_names
#     => ["0", "1", "2", "3", ... , "_Total"]
#   data["Processor"].instances[5].name
#     => "_Total"
#   data["Processor"].instances[5].counters
#     => {"% Processor Time"=>1880217871093, "% User Time"=>41857187500, ...}
#
# Public API:
#   * HKeyPerfDataReader::Reader#read()
#      return hash of PerfObject

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
        puts("HKeyPerfDataReader: Invalid performance block header")
        return nil
      end

      perf_objects = {}

      offset = header.headerLength
      header.numObjectTypes.times do
        perf_object, total_byte_length, success = read_perf_object(offset)
        unless success
          if total_byte_length.nil?
            print_debug("HKeyPerfDataReader: Can not continue. Stop reading.")
            break
          else
            print_debug("HKeyPerfDataReader: Skip this object and continue reading.")
            offset += total_byte_length
            next
          end
        end

        # print_debug_perf_object(perf_object)

        # TODO some object names are nil. Exclude them temporarily.
        perf_objects[perf_object.name] = perf_object unless perf_object.name.nil?
        offset += total_byte_length
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
      perf_object.instances.each do |instance|
        print_debug("  instance: #{instance.name}")
        print_debug("    counters: #{instance.counters}")
        print_debug("")
      end
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

    def read_perf_object(object_start_offset)
      cur_offset = object_start_offset

      object_type = RawType::PerfObjectType.new(:endian => endian)
        .read(@raw_data[cur_offset..]).snapshot
      cur_offset += object_type.headerLength

      perf_object = ConvertedType::PerfObject.new(
        @counter_name_reader.read(object_type.objectNameTitleIndex)
      )

      print_debug("object name: #{perf_object.name}")

      cur_offset = set_couner_defs_to_object(
        perf_object, object_type.numCounters, cur_offset
      )

      if object_type.numInstances == PERF_NO_INSTANCES || object_type.numInstances == 0
        set_counters_to_no_instance_object(
          perf_object,
          object_start_offset + object_type.definitionLength,
        )
      else
        set_counters_to_multiple_instance_object(
          perf_object,
          object_type.numInstances,
          object_start_offset + object_type.definitionLength,
        )
      end

      return perf_object, object_type.totalByteLength, true
    rescue => e
      print_debug("HKeyPerfDataReader: error occurred: objectname: #{perf_object&.name}, message: #{e.message}")
      return nil, object_type&.totalByteLength, false
    end

    def set_couner_defs_to_object(perf_object, num_of_counters, counter_def_start_offset)
      cur_offset = counter_def_start_offset

      num_of_counters.times do
        counter_def = RawType::PerfCounterDefinition.new(:endian => endian)
          .read(@raw_data[cur_offset..]).snapshot

        perf_object.add_counter_def(
          ConvertedType::PerfCounterDef.new(
            @counter_name_reader.read(counter_def.counterNameTitleIndex),
            counter_def,
          )
        )

        cur_offset += counter_def.byteLength
      end

      cur_offset
    end

    def set_counters_to_no_instance_object(perf_object, counter_block_offset)
      # to unify data format, use no name instance for a container for the counters
      instance = ConvertedType::PerfInstance.new("")

      perf_object.counter_defs.each do |counter_def|
        instance.add_counter(
          counter_def.name,
          read_counter_value(
            counter_def,
            counter_block_offset + counter_def.counter_offset, 
          )
        )
      end

      perf_object.add_instance(instance)
    end

    def set_counters_to_multiple_instance_object(
      perf_object, num_of_instances, first_instance_offset
    )
      cur_instance_offset = first_instance_offset

      num_of_instances.times do
        instance_def = RawType::PerfInstanceDefinition.new(:endian => endian)
          .read(@raw_data[cur_instance_offset..]).snapshot

        name_offset = cur_instance_offset + instance_def.nameOffset
        instance_name = @raw_data[
          name_offset..name_offset+instance_def.nameLength-1
        ].encode("UTF-8", "UTF-16LE").strip

        instance = ConvertedType::PerfInstance.new(instance_name)

        counter_block_offset = cur_instance_offset + instance_def.byteLength

        counter_block = RawType::PerfCounterBlock.new(:endian => endian)
          .read(@raw_data[counter_block_offset..]).snapshot

        perf_object.counter_defs.each do |counter_def|
          instance.add_counter(
            counter_def.name,
            read_counter_value(
              counter_def,
              counter_block_offset + counter_def.counter_offset, 
            )
          )
        end

        perf_object.add_instance(instance)
        cur_instance_offset = counter_block_offset + counter_block.byteLength
      end
    end

    def read_counter_value(counter_def, offset)
      # Currently counter data is limited to DWORD and ULONGLONG data types
      #   ref: https://docs.microsoft.com/en-us/windows/win32/perfctrs/retrieving-counter-data
      # We don't need to consider `counterType` unless we need to format the value for output.
      endian_mark = @is_little_endian ? "<" : ">"
      case counter_def.counter_size
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
      puts("HKeyPerfDataReader: RegQueryValueExW : ret=#{ret}") # for debug

      # https://docs.microsoft.com/en-us/windows/win32/perfctrs/using-the-registry-functions-to-consume-counter-data
      # TODO The document above says we must call `RegCloseKey`, but this returns error code: 6 (ERROR_INVALID_HANDLE)
      ret = API::RegCloseKey.call(Constants::HKEY_PERFORMANCE_DATA)
      puts("HKeyPerfDataReader: RegCloseKey : ret=#{ret}") # for debug

      data
    end

    def self.read_counter_name_table
      # https://docs.microsoft.com/en-us/windows/win32/perfctrs/retrieving-counter-names-and-help-text
      type = packdw(0)
      size = packdw(128*1024*1024) # 128kb (for now)
      data = "\0".force_encoding("ASCII-8BIT") * unpackdw(size)
      ret = API::RegQueryValueExW.call(Constants::HKEY_PERFORMANCE_DATA, make_wstr("Counter 009"), 0, type, data, size)
      puts("HKeyPerfDataReader: RegQueryValueExW : ret=#{ret}") # for debug

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
