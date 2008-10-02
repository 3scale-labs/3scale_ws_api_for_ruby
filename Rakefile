require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Run unit tests.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = '3scale interface'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

spec = Gem::Specification.new do |s|
  s.name = '3scale_interface'
  s.version = '0.4.0'
  s.summary = '3scale contract management API for Ruby.'
  s.authors = ['Josep M. Pujol', 'Adam Ciganek']
  s.email = 'jmpujol @nospam@ gmail.com'

  s.add_dependency 'hpricot', '>= 0.6.161'
  
  s.files = FileList['lib/**/*.rb', 'test/**/*.rb', 'init.rb']
  s.test_files = FileList['test/**/*_test.rb']

  s.has_rdoc = true
  s.extra_rdoc_files = ['README']
end

Rake::GemPackageTask.new(spec) do |package|
    package.need_tar = true
end
