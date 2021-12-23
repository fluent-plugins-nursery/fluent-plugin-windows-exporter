# Window exporter development

## Getting started

You'll need a Windows machine with Ruby and Git installed.

 * Git for Windows (https://gitforwindows.org/)
 * Ruby installer with devkit (https://rubyinstaller.org/)

## How to run the development version

 1. Clone this repository on Windows:
    ```sh
    % git clone https://github.com/fluent-plugins-nursery/fluent-plugin-windows-exporter/
    ```
 2. Run the following commands on RubyInstaller prompt:
    ```sh
    % cd fluent-plugin-windows-exporter
    % gem install bundler
    % bundle install
    ```
 3. Launch Fluentd:
    ```sh
    % type test.conf
    <source>
      @type windows_exporter
    </source>
    <match windows.metrics>
      @type stdout
    </match>
    % bundle exec fluentd -c test.conf
    ```

## How to release a new version

Create an annotated tag on GitHub and push gems:

```sh
$ git tag -a v1.0.0 -m v1.0.0
$ git push origin --tags
$ rake build
$ gem push *.gem
```

We maintain the release announcements on GitHub. Create a new release on ["Release" page](https://github.com/fluent-plugins-nursery/fluent-plugin-windows-exporter/releases)

## How to run the tests

Test codes are in `test/plugin/`.

```sh
% bundle exec rake test
```

You can compare the output values with Prometheus windows exporter.

* Install Prometheus windows exporter
* Run it by ".\windows_exporter.exe --collectors.enabled="cpu,memory,logical_disk,net,os""
* Run test codes of this plugin

Then `WindowsExporterInputTest::test_record_values_with_prometheus_windows_exporter` test prints out the comparison results.  
You can change the output threshold by editing the test code.
