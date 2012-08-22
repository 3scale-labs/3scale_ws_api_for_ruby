# encoding: utf-8
require "rubygems"
require "bundler/setup"

require 'rake'
require 'rake/testtask'
require 'rdoc/task'

desc 'Default: run unit tests.'
task :default => :test

desc 'Run unit tests.'
Rake::TestTask.new(:test) do |t|
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = '3scale API Management Client'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'

  Jeweler::Tasks.new do |gemspec|
    gemspec.name     = '3scale_client'
    gemspec.summary  = 'Client for 3scale Web Service Management System API'
    gemspec.description = <<END
This gem allows to easily connect an application that provides a Web Service with the 3scale API Management System to authorize it's users and report the usage.
END
    gemspec.email    = 'support@3scale.net'
    gemspec.homepage = 'http://www.3scale.net'
    gemspec.authors  = ['Adam Cigánek', 'Tiago Macedo', 'Joaquin Rivera Padron (joahking)']

    gemspec.add_dependency 'nokogiri'
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end
