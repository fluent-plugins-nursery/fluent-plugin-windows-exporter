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
    assert_equal "test", d.instance.tag
  end

  def test_all_records
    d = create_driver(BASE_CONFIG)
    d.run(expect_emits: 1, timeout: 10)

    not_found_records = []
    ExpectedData::RECORDS.each do |expected_record|
      has_found = false
      d.events.each do |tag, datetime, record|
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

      not_found_records.append(expected_record)
    end

    assert_equal(
      0,
      not_found_records.length,
      "Not found: #{not_found_records.map { |r| r["name"] }.join(",")}"
    )
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::WindowsExporterInput).configure(conf)
  end
end
