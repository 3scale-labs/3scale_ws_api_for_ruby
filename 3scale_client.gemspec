# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require '3scale/client/version'

Gem::Specification.new do |spec|
  spec.name          = "3scale_client"
  spec.version       = ThreeScale::Client::VERSION
  spec.authors       = ["Michal Cichra"] | ['Adam Cigánek', 'Tiago Macedo', 'Joaquin Rivera Padron (joahking)']
  spec.email         = ["support@3scale.net"]
  spec.description   = "This gem allows to easily connect an application that provides a Web Service with the 3scale API Management System to authorize it's users and report the usage."
  spec.summary       = 'Client for 3scale Web Service Management System API'
  spec.homepage      = "http://www.3scale.net"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rdoc"
  spec.add_dependency 'nokogiri'
end
