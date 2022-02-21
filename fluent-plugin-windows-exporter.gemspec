require 'rake'

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |s|
  s.name     = "fluent-plugin-windows-exporter"
  s.version  = "1.0.0"
  s.license  = "Apache-2.0"
  s.summary  = "Fluentd plugin to collect Windows metrics (memory, cpu, network, etc.)"
  s.authors  = ["Fujimoto Seiji", "Fukuda Daijiro"]
  s.email    = ["fujimoto@clear-code.com", "fukuda@clear-code.com"]
  s.files    = FileList['lib/**/*.rb', 'LICENSE', 'README.md'].to_a
  s.homepage = "https://github.com/fluent-plugins-nursery/fluent-plugin-windows-exporter"

  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", '~> 2.0'
  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "test-unit", "~> 3.3"

  s.add_runtime_dependency "bindata", '~> 2.4'
  s.add_runtime_dependency "fluentd", [">= 1.0.0", "< 2"]
end
