require "helper"
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
            record.key?("labels") && record["labels"][k] == v
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
end
