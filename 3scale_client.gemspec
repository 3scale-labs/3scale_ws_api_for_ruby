# encoding: UTF-8

Gem::Specification.new do |s|
  s.name = %q{3scale_client}
  s.version = "2.2.10"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Adam Cigánek", "Tiago Macedo"]
  s.description = %q{This gem allows to easily connect an application that provides a Web Service with the 3scale API Management System to authorize its users and report the usage.
}
  s.email = %q{adam@3scale.net tiago@3scale.net}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    ".gitignore",
     "3scale_client.gemspec",
     "Gemfile",
     "LICENCE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/3scale/authorize_response.rb",
     "lib/3scale/client.rb",
     "lib/3scale/response.rb",
     "test/client_test.rb",
     "test/remote_test.rb"
  ]
  s.homepage = %q{http://www.3scale.net}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{Client for 3scale Web Service Management System API}
  s.test_files = [
    "test/remote_test.rb",
     "test/client_test.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<nokogiri>, [">= 0"])
    else
      s.add_dependency(%q<nokogiri>, [">= 0"])
    end
  else
    s.add_dependency(%q<nokogiri>, [">= 0"])
  end

  s.add_development_dependency 'fakeweb'
  s.add_development_dependency 'jeweler'
  s.add_development_dependency 'mocha'
end

