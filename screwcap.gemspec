# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "screwcap"
  s.version     = "0.8.3"
  s.platform    = Gem::Platform::RUBY
  s.author      = "Grant Ammons"
  s.email       = ["grant@pipelinedealsco.com"]
  s.homepage    = "http://github.com/gammons/screwcap"
  s.summary     = "Screwcap is a wrapper of Net::SSH and allows for easy configuration, organization, and management of running tasks on remote servers."

  s.add_dependency('net-ssh','>=2.0.23')
  s.add_dependency('net-ssh-gateway','>=1.0.1')
  s.add_dependency('net-scp','>=1.0.4')

  s.add_development_dependency "mocha"
  s.add_development_dependency "rake"
  s.add_development_dependency "rcov"
  s.add_development_dependency "rspec", '1.3.1'
  s.add_development_dependency "ruby-debug"

  s.rubyforge_project = 'screwcap'

  s.files        = Dir.glob("{bin,lib}/**/*") + %w(README.md screwcap.gemspec)
  s.require_path = 'lib'
end
