# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "scaltainer/version"

Gem::Specification.new do |spec|
  spec.name          = "scaltainer"
  spec.version       = Scaltainer::VERSION
  spec.authors       = ["Hossam Hammady"]
  spec.email         = ["github@hammady.net"]

  spec.summary       = %q{Autoscale docker swarm services based on application metrics and more}
  spec.description   = %q{A ruby gem inspired by HireFire to autoscale docker swarm services.
    Metrics can be standard average response time, New Relic web metrics, queue size for workers, ...}
  spec.homepage      = "https://github.com/hammady/scaltainer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency 'rspec', '~> 3.5'
  spec.add_development_dependency 'coderay', '~> 1.1'
  spec.add_development_dependency 'coveralls', '~> 0.8'

  spec.add_runtime_dependency 'excon', '>= 0.47.0'
  spec.add_runtime_dependency "docker-api"
  spec.add_runtime_dependency "kubeclient"
  spec.add_runtime_dependency "dotenv"
end
