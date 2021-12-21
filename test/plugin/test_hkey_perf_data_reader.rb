require "helper"
require 'benchmark'
require "fluent/plugin/hkey_perf_data_reader.rb"

class HKeyPerfDataReaderTest < Test::Unit::TestCase
  def test_read_default
    reader = HKeyPerfDataReader::Reader.new()
    result = reader.read
    assert(result.keys.size > 0)
  end

  def test_whitelist
    white_list = [
      "Processor Information",
      "Memory",
    ]
    reader = HKeyPerfDataReader::Reader.new(
      object_name_whitelist: white_list
    )

    result = reader.read

    assert_equal(white_list.size, result.keys.size)
    white_list.each do |name|
      assert(result.key?(name))
    end
  end

  def test_read_speed
    # The expected speed will change depending on the environment,
    # but want to find out if it is abnormally slow.
    threshold_time = 1.0

    white_list = [
      "Processor Information",
      "LogicalDisk",
      "Memory",
      "Network Interface",
      "Paging File",
    ]
    reader = HKeyPerfDataReader::Reader.new(
      object_name_whitelist: white_list
    )

    times_to_read = []
    3.times do
      result = Benchmark.realtime do
        reader.read
      end
      times_to_read.append(result)
    end

    avg = times_to_read.sum / times_to_read.size
    puts("[HKeyPerfDataReaderTest::test_read_speed] Average reading time: #{avg} sec")
    assert(avg < threshold_time)
  end
end
