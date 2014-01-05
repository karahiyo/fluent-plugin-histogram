# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-histogram"
  spec.version       = "0.0.12"
  spec.authors       = ["SHIMIZU Yusuke"]
  spec.email         = "a.ryuklnm@gmail.com"
  spec.description   = "Combine inputs data and make histogram which help to detect a hotspot."
  spec.summary       = "Combine inputs data and make histogram which help to detect a hotspot."
  spec.homepage      = "https://github.com/karahiyo/fluent-plugin-histogram"
  spec.license       = "APLv2"

  spec.rubyforge_project = "fluent-plugin-histogram"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", ">= 0.9.2"
  spec.add_development_dependency "fluentd", "~> 0.10.9"
  spec.add_runtime_dependency "fluent-mixin-config-placeholders", "~> 0.2.3"

end
