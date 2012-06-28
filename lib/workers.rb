# encoding: UTF-8

require 'pathname'

require 'bundler/setup'
require 'redis'

require 'workers/monitrc'
require 'workers/process'
require 'workers/worker'
require 'workers/version'

module Workers
  extend Worker
  extend Monitrc
end
