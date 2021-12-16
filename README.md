# fluent-plugin-windows-exporter

[Fluentd](https://fluentd.org/) plugin to collect Windows metrics.

 | Platform | Support Version       |
 | -------- | --------------------- |
 | Fluentd  | Fluentd v1.x          |
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
| `scrape_interval`| The interval time between data collection | `5` |
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

## Copyright

* Copyright(c) 2021- Fujimoto Seiji, Fukuda Daijiro
* License
  * Apache License, Version 2.0
