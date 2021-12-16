# fluent-plugin-windows-exporter

[Fluentd](https://fluentd.org/) input plugin to do something.

## How to start development

 1. Install Git for Windows
 2. Install Ruby with devkit from https://rubyinstaller.org/
 3. Clone this repository on Windows
    ```console
    $ git clone https://github.com/fluent-plugins-nursery/fluent-plugin-windows-exporter/
    ```
 4. Run the following
    ```console
    $ cd fluent-plugin-windows-exporter
    $ gem install bundler --version=2.1.4
    $ bundle install
    ```
 5. Run Fluentd as follows:
    ```console
    $ type test.conf
    <source>
      @type windows_exporter
      tag test.log
      scrape_interval 3
    </source>
    <match test.**>
      @type stdout
    </match>
    $ bundle exec fluentd -c test.conf
    ```

## Installation

### RubyGems

```
$ gem install fluent-plugin-windows-exporter
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-windows-exporter"
```

And then execute:

```
$ bundle
```

## Configuration

### tag (string) (optional)

Tag of the output events

Default value: `windows.metrics`.

### scrape_interval (time) (optional)

The interval time between data collection

Default value: `5`.

### cpu (bool) (optional)

Enable cpu collector

Default value: `true`.

### logical_disk (bool) (optional)

Enable disk collector

Default value: `true`.

### memory (bool) (optional)

Enable memory collector

Default value: `true`.

### net (bool) (optional)

Enable network collector

Default value: `true`.

### os (bool) (optional)

Enable OS collector

Default value: `true`.

## Copyright

* Copyright(c) 2021- Fujimoto Seiji, Fukuda Daijiro
* License
  * Apache License, Version 2.0
