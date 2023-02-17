# fluent-plugin-windows-exporter

[Fluentd](https://fluentd.org/) plugin to collect Windows metrics.

 | Platform |        Support Version         |
 |----------|--------------------------------|
 | Fluentd  | Fluentd v1.x                   |
 | Ruby     | Ruby 2.7.x / 3.1.x / 3.2.x     |
 | OS       | Windows Server 2008R2 or later |

This is a Fluentd port of [Prometheus' Windows exporter](https://github.com/prometheus-community/windows_exporter).
This plugin emits metrics as event stream, so can be used in combination with any output plugins.

## Installation

```sh
% gem install fluent-plugin-windows-exporter
```

## Configuration

### List of Options

| Option           | Description              | Default           |
| ---------------- | ------------------------ | ----------------- |
| `tag`            | Tag of the output events | `windows.metrics` |
| `scrape_interval`| The interval time between data collection | `60` |
| `cpu`            | Enable cpu collector     | `true` |
| `logical_disk`   | Enable disk collector    | `true` |
| `memory`         | Enable memory collector  | `true` |
| `net`            | Enable network collector | `true` |
| `os`             | Enable OS collector      | `true` |

### Example Configuration

```
<source>
  @type windows_exporter
  tag windows.metrics  # optional
  scrape_interval 60   # optional
  cpu true             # optional
  memory true          # optional
  os trues             # optional
  net true             # optional
  logical_disk true    # optional
</source>
```

### Output format

This plugin is desinged to export the equivalent amount of information with Prometheus.
Here is what a typical event looks like:

```ruby
{
    "type": "gauge",
    "name": "windows_memory_system_code_resident_bytes",
    "desc": "(SystemCodeResidentBytes)",
    "labels": {},
    "value": 8192
}
```

This is equivalent to the following exposition of Prometheus's Windows exporter:

```
# HELP windows_memory_system_code_resident_bytes (SystemCodeResidentBytes)
# TYPE windows_memory_system_code_resident_bytes gauge
windows_memory_system_code_resident_bytes 8192
```

For further details, please refer to [Prometheus' exposition format specification](https://github.com/prometheus/docs/blob/main/content/docs/instrumenting/exposition_formats.md).

## Copyright

* Copyright(c) 2021- Fujimoto Seiji, Fukuda Daijiro
* License
  * Apache License, Version 2.0
