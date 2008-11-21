Gem::Specification.new do |s|
  s.name = '3scale_ws_api_for_ruby'
  s.version = '0.4.7'
  s.summary = '3scale web service management API for Ruby.'
  s.authors = ['Adam Cigánek', 'Josep M. Pujol']
  s.email = 'adam@3scale.net'
  s.homepage = 'http://www.3scale.net'

  s.add_dependency 'hpricot', '>= 0.6.161'
  
  s.files = Dir['lib/**/*.rb'] + Dir['test/**/*.rb'] + ['init.rb', 'Rakefile']
  s.test_files = Dir['test/**/*_test.rb']

  s.has_rdoc = true
  s.extra_rdoc_files = ['README']
end
