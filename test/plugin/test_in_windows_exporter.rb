require "helper"
require "net/http"
require "fluent/plugin/in_windows_exporter.rb"
require_relative "data"

class WindowsExporterInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  BASE_CONFIG = %[
    @type windows_exporter
    tag test
    scrape_interval 10
  ]

  def test_configure
    d = create_driver(BASE_CONFIG)
    assert_equal("test", d.instance.tag)
    assert_equal(10, d.instance.scrape_interval)
  end

  def test_configure2
    config = %[
      @type windows_exporter
      tag test2
      scrape_interval 20
      memory true
      cpu false
      logical_disk false
      net false
      os false
    ]

    d = create_driver(config)

    assert_equal("test2", d.instance.tag)
    assert_equal(20, d.instance.scrape_interval)
    assert_equal(true, d.instance.memory)
    assert_equal(false, d.instance.cpu)
    assert_equal(false, d.instance.logical_disk)
    assert_equal(false, d.instance.net)
    assert_equal(false, d.instance.os)
  end

  def test_all_records
    d = create_driver(BASE_CONFIG)
    d.run(expect_emits: 1, timeout: 10)

    missing_records = explore_missing_records(ExpectedData::RECORDS, d.events)

    assert_equal(
      0,
      missing_records.size,
      "Not found: #{missing_records.map { |r| r["name"] }.join(",")}"
    )
  end

  def test_only_memory_records
    config = %[
      @type windows_exporter
      tag test
      scrape_interval 10
      memory true
      cpu false
      logical_disk false
      net false
      os false
    ]

    d = create_driver(config)
    d.run(expect_emits: 1, timeout: 10)

    expected_records = ExpectedData::RECORDS.select {
      |r| r["name"].start_with?("windows_memory")
    }

    assert_equal(expected_records.size, d.events.size)

    missing_records = explore_missing_records(expected_records, d.events)

    assert_equal(
      0,
      missing_records.size,
      "Not found: #{missing_records.map { |r| r["name"] }.join(",")}"
    )
  end

  # This test is for comparing values with local Prometheus windows exporter.
  # This runs only when Prometheus windows exporter is running and the uri `http://localhost:9182/metrics` returns data.
  # Currently, this test does not do asserting.
  # Prepare:
  # * Install Prometheus windows exporter.
  # * Run windows exporter by `.\windows_exporter.exe --collectors.enabled="cpu,memory,logical_disk,net,os"`.
  def test_record_values_with_prometheus_windows_exporter
    _, success = get_data_from_prometheus_windows_exporter
    unless success
      return
    end

    print_all_results = false
    diff_percentage_threshold = 10.0
    try_count = 3
    # to fix diffrences with prometheus windows exporter
    name_fix_hash = {
      "windows_os_process_memory_limit_bytes" => "windows_os_process_memory_limix_bytes",
      "windows_net_current_bandwidth_bytes" => "windows_net_current_bandwidth",
    }

    puts("\n")
    puts("WindowsExporterInputTest::test_record_values_with_prometheus_windows_exporter")
    puts("\n")


    try_count.times do |try_number|
      puts("try##{try_number}")
      puts("| %-100s | %-20s | %-20s | %-20s |" % ["Metrics name", "Plugin value", "Prometheus value", "Diff percentage"])
  
      d = create_driver(BASE_CONFIG)
      d.run(expect_emits: 1, timeout: 10)
      prometheous_records, success = get_data_from_prometheus_windows_exporter
      unless success
        puts("error to get records from prometheus windows exporter.")
        next
      end
  
      diffs = []
  
      d.events.each do |tag, datetime, record|
        # labels of timezone tend not to match, and not so important to compare values.
        next if record["name"] == "windows_os_timezone"

        p_record = find_same_record(record, prometheous_records, name_fix_hash)
        if p_record.nil?
          puts(
            "| %-100s | %-20s | %-20s | %-20s |" % [
              "#{record["name"]} #{record["labels"]}", record["value"], "NotFound", "NotFound"
            ]
          )
          next
        end

        p_value = p_record["value"]
        # We use byte type value, so need to convert if prometheus uses "windows_net_current_bandwidth", not "windows_net_current_bandwidth_bytes".
        if p_record["name"] == "windows_net_current_bandwidth"
          p_value = p_record["value"] / 8
        end

        diff = p_value != 0 ? record["value"] / p_value * 100 - 100 : record["value"]
        diff = diff.round(1)
        diffs.append(diff)

        if print_all_results
          puts(
            "| %-100s | %-20s | %-20s | %-20s |" % [
              "#{record["name"]} #{record["labels"]}", record["value"], p_value, "#{diff}%"
            ]
          )
          next
        end

        if diff_percentage_threshold < diff
          puts(
            "| %-100s | %-20s | %-20s | %-20s |" % [
              "#{record["name"]} #{record["labels"]}", record["value"], p_value, "#{diff}%"
            ]
          )
        end
      end
  
      puts("average absolute diff: #{(diffs.map{|d| d.abs}.sum / diffs.size).round(3)}% [in #{diffs.size} records]")
    end
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::WindowsExporterInput).configure(conf)
  end

  # expected_records:
  #  list of {"name" => "", "labels" => {"" => ""}}
  #  or list of {"name" => ""}
  def explore_missing_records(expected_records, events)
    missing_records = []

    expected_records.each do |expected_record|
      has_found = false
      events.each do |tag, datetime, record|
        next unless record["name"] == expected_record["name"]

        if expected_record.key?("labels")
          next unless expected_record["labels"].all? { |k, v|
            record.key?("labels") && (record["labels"][k.to_s] == v || record["labels"][k.to_sym] == v)
          }
        end

        has_found = true
        break
      end

      next if has_found

      missing_records.append(expected_record)
    end

    missing_records
  end

  def get_data_from_prometheus_windows_exporter(uri = "http://localhost:9182/metrics")
    response = Net::HTTP.get_response(URI(uri))
    return nil, false unless response.code == "200"

    lines = response.body.split("\n")
      .map { |line| line.strip}
      .select { |line| !line.empty? && !line.start_with?("#") }

    prometheous_records = []

    lines.each do |line|
      record = {
        "name" => "",
        "value" => 0.0,
        "labels" => {},
      }
      i = line.index("{")

      no_label_data = i.nil?
      if no_label_data
        i = line.index(" ")
        record["name"] = line[0..i-1]
        record["value"] = line[i+1..].to_f
      else
        record["name"] = line[0..i-1]
        end_label_i = line.index("}")
        record["value"] = line[end_label_i+1..].to_f
        label = line[i+1..end_label_i-1]
        while true
          i = label.index("=\"")
          break if i.nil?
          key = label[0..i-1]
          end_val_i = label.index("\"", i+2)
          val = label[i+2..end_val_i-1]
          record["labels"][key] = val
          label = label[end_val_i+2..]
          break if label.to_s.empty?
        end
      end

      prometheous_records.append(record)
    end

    return prometheous_records, true
  end

  def is_same_hash?(h1, h2)
    h1.to_a.map { |k, v| [k.to_s, v] } == h2.to_a.map { |k, v| [k.to_s, v] }
  end

  def find_same_record(record, records, name_fix_hash)
    r = records.find { |r| r["name"] == record["name"] && is_same_hash?(r["labels"], record["labels"]) }
  
    return r unless r.nil?

    return nil unless name_fix_hash.key?(record["name"])

    return records.find { |r|
      r["name"] == name_fix_hash[record["name"]] && is_same_hash?(r["labels"], record["labels"])
    }
  end
end
