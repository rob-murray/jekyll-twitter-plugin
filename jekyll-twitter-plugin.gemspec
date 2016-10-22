# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "jekyll-twitter-plugin"
  spec.version       = "2.0.0.beta"
  spec.authors       = ["Rob Murray"]
  spec.email         = ["robmurray17@gmail.com"]
  spec.summary       = "A Liquid tag plugin for Jekyll that renders Tweets from Twitter API"
  spec.homepage      = "https://github.com/rob-murray/jekyll-twitter-plugin"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.0.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "byebug" if RUBY_VERSION >= "2.0"
end
