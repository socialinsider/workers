# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "workers/version"

Gem::Specification.new do |s|
  s.name        = "workers"
  s.version     = Workers::VERSION
  s.authors     = ["Karel Minarik","Vojtech Hyza"]
  s.email       = ["karmi@karmi.cz","vhyza@vhyza.eu"]
  s.homepage    = ""
  s.summary     = %q{Background jobs with forking}

  s.rubyforge_project = "workers"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'erubis'
  s.add_dependency 'sinatra'
  s.add_dependency 'thin'
  s.add_dependency 'redis'
  s.add_dependency 'em-hiredis'
  s.add_dependency 'websocket-rack'
  s.add_dependency 'activesupport'
  s.add_dependency 'i18n'

  s.add_development_dependency 'shoulda'
  s.add_development_dependency 'turn'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'yard'
end
