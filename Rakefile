require 'bundler/gem_tasks'
require 'rake/testtask'

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

ENV['WORKERS_PID_DIR'] ||= File.expand_path('../tmp/pids', __FILE__)

require 'workers'
require 'workers/tasks'

task :default do
  Rake::Task['workers:groups'].invoke
  puts "Display information on all available Rake tasks: rake -D workers"
end
