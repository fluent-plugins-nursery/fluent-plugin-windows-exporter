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

## How to run the tests

Test codes are in `test/plugin/`.

```sh
% bundle exec rake test
```
