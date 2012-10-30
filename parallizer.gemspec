# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

require "parallizer/version"

Gem::Specification.new do |s|
  s.name        = "parallizer"
  s.version     = Parallizer::VERSION
  s.authors     = ["Michael Pearce"]
  s.email       = ["michaelgpearce@yahoo.com"]
  s.homepage    = "http://github.com/michaelgpearce/parallizer"
  s.summary     = %q{Execute your service layer in parallel}
  s.description = %q{Execute your service layer in parallel.}

  s.rubyforge_project = "parallizer"

  s.files = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency 'work_queue'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 2.9.0'
  s.add_development_dependency 'always_execute', '~> 0.1.1'
end
