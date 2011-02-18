# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "angry_shell/version"

Gem::Specification.new do |s|
  s.name        = "angry_shell"
  s.version     = AngryShell::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Lachie Cox"]
  s.email       = ["lachie.cox@plus2.com.au"]
  s.homepage    = "http://rubygems.org/gems/angry_shell"
  s.summary     = %q{Shell}
  s.description = %q{}

  s.rubyforge_project = "angry_shell"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
