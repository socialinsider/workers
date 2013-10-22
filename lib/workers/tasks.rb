# encoding: UTF-8

# To launch multiple workers, run me with:
#
#     $ rake workers:start_all WORKERS_LAUNCHER=/path/to/launcher.rb WORKERS_HEARTBEAT=300 WORKERS_GROUP=my_group
#
# To launch single worker, run me with:
#
#     $ rake workers:start WORKERS_JOBPATH=some/path WORKERS_JOBCLASS=MyWorkerClass WORKERS_NAME=test WORKERS_HEARTBEAT=300
#
# The tasks create PID files in the directory specified as the `WORKERS_PID_DIR` environment
# variable, by default in the `$CWD/pids`.
#
# The tasks automatically create a configuration file for Monit in the directory
# specified as the `WORKERS_MONITRC_DIR` environment variable, by default in `$CWD/monit/conf.d/`.
#
# Run the tasks with the `WORKERS_DEBUG` environment variable set to `true` to see job output.
# Set the `WORKERS_DEBUG` variable to `verbose` to see debugging output.

# encoding: UTF-8

$LOAD_PATH.unshift File.expand_path('../../../', __FILE__)

require 'rake'
require 'active_support/inflector'

require 'workers'

STDOUT.sync = true

trap :INT do
  puts "Exiting #{Process.pid}...", '-'*120
  exit
end

ENV['WORKERS_PID_DIR']   ||= File.join(Dir.pwd, 'pids')
ENV['WORKERS_HEARTBEAT'] ||=  '60'

namespace :workers do

  desc "Launch all workers for a group. Pass path to launcher script as the WORKERS_LAUNCHER environment variable " +
       "and group name as the WORKERS_GROUP environment variable. Pass the path to directory containing PID files as " +
       "the WORKERS_PID_DIR environment variable, and the path to the directory containing Monit configuration files " +
       "as the WORKERS_MONITRC_DIR environment variable."
  task :start_all do
    raise ArgumentError, "You must pass a path to the launcher Ruby file as WORKERS_LAUNCHER environment variable" unless ENV['WORKERS_LAUNCHER']
    raise ArgumentError, "You must pass a group name as WORKERS_GROUP environment variable" unless ENV['WORKERS_GROUP']

    $LOAD_PATH << Dir.pwd

    puts "[master] starting... (pid: #{Process.pid})", ""
    $0=$PROCESS_NAME="[master] (Started at #{Time.now})"

    at_exit do
      puts '='*120, "Master exiting at #{Time.now}, leaving #{Dir["#{ENV['WORKERS_PID_DIR']}/#{ENV['WORKERS_GROUP']}/*.pid"].size} workers.", ''
    end

    require ENV['WORKERS_LAUNCHER']
  end

  desc "Terminate all workers in GROUP. Pass the group name as the GROUP environment variable."
  task :stop_all do
    puts "#{Dir["#{ENV['WORKERS_PID_DIR']}/#{ENV['WORKERS_GROUP']}/*.pid"].size} workers in #{ENV['GROUP']} group",
         "PID directory in: #{ENV['WORKERS_PID_DIR']}/#{ENV['WORKERS_GROUP']}/*.pid", '-'*120
    Dir["#{ENV['WORKERS_PID_DIR']}/#{ENV['WORKERS_GROUP']}/*.pid"].each do |file|
      pid = File.read(file)
      puts "Killing #{pid}..."
      begin
        Process.kill('INT', pid.to_i)
      rescue Errno::ESRCH
        puts "[!] Cannot quit process with PID #{pid}, removing pidfile..."
        File.delete(file)
      end
      sleep 1
    end
  end

  desc "Launch single worker. Pass path to job class as the WORKERS_JOBCLASS environment variable and " +
       "the name as the WORKERS_NAME environment variable. Pass the path to directory containing PID files as " +
        "the WORKERS_PID_DIR environment variable, and the path to the directory containing Monit configuration files " +
        "as the WORKERS_MONITRC_DIR environment variable."
  task :start do
    raise ArgumentError, "You must pass a job class name as the WORKERS_JOBCLASS environment variable" unless ENV['WORKERS_JOBCLASS']
    raise ArgumentError, "You must pass an account ID as the WORKERS_NAME environment variable."    unless ENV['WORKERS_NAME']
    raise ArgumentError, "You must pass a group name as WORKERS_GROUP environment variable"            unless ENV['WORKERS_GROUP']

    require 'active_support/inflector'

    group                    = ENV['WORKERS_GROUP']
    name                     = ENV['WORKERS_NAME']
    ENV['WORKERS_JOBPATH'] ||= Dir.pwd

    puts "[launcher] starting #{name} in group #{group}... (pid: #{Process.pid})", ""
    $0=$PROCESS_NAME="[launcher] (Started at #{Time.now})"

    require File.join(ENV['WORKERS_JOBPATH'], ENV['WORKERS_JOBCLASS'].demodulize.underscore)

    Workers::worker group,
                    { name: name },
                    ENV['WORKERS_HEARTBEAT'].to_i,
                    lambda { |payload| ENV['WORKERS_JOBCLASS'].constantize.perform(payload) }
    Workers::monitrc group,
                     {name: name},
                     ENV['WORKERS_HEARTBEAT'].to_i
  end

  desc "Terminate single worker in specific group. Pass a name as the WORKERS_NAME environment variable " +
       "and the group name as the WORKERS_GROUP environment variable."
  task :stop do
    raise ArgumentError, "You must pass an account ID as the WORKERS_NAME environment variable." unless ENV['WORKERS_NAME']
    raise ArgumentError, "You must pass a group name as the WORKERS_GROUP environment variable."    unless ENV['WORKERS_GROUP']
    filename = "#{ENV['WORKERS_PID_DIR']}/#{ENV['WORKERS_GROUP']}/#{ENV['WORKERS_NAME']}.pid"

    begin
      pid = File.read(filename).strip
    rescue Errno::ENOENT => e
      puts "[ERROR] Cannot terminate worker:", e.inspect
      exit(1)
    end

    begin
      puts "Terminating worker with PID #{pid} in #{filename}..."
      Process.kill('INT', pid.to_i)
    rescue Errno::ESRCH => e
      puts "[ERROR] Process with PID #{pid} does not exists:", e.inspect
      exit(1)
    end
  end

  desc "Display worker GROUPS. Based on WORKERS_PID_DIR contents."
  task :groups do
    groups = Dir.entries(ENV['WORKERS_PID_DIR']).reject { |d| d =~ /^\./ }
    puts '='*120, "Groups in '#{ENV['WORKERS_PID_DIR']}' (#{groups.size})", '='*120
    groups.each do |group|
      pid_files = Dir.entries( File.join(ENV['WORKERS_PID_DIR'], group) ).reject { |d| d =~ /^\./ }
      puts "#{group.ljust(20)} | #{pid_files.size} PID files", '-'*120
    end

  end

  desc "Display statistics about workers/fetchers. Pass group name as the GROUP environment variable."
  task :stats do
    raise ArgumentError, "You must pass the group name as WORKERS_GROUP environment variable" unless ENV['WORKERS_GROUP']

    redis = Redis.new
    pids  = Dir["#{ENV['WORKERS_PID_DIR']}/#{ENV['WORKERS_GROUP']}/*.pid"]
    if pids.empty?
      puts '-'*120, "[!] No workers running, exiting...", '-'*120
      exit(1)
    end

    processes = Workers::WorkerProcess.all(ENV['WORKERS_GROUP'], ENV['WORKERS_PID_DIR'])

    total   = redis.get("#{ENV['WORKERS_GROUP']}:jobs:total").to_i
    success = redis.get("#{ENV['WORKERS_GROUP']}:jobs:success").to_i
    puts '-'*120, "#{processes.size} workers running [#{pids.size} pidfiles found] " +
                  "total/success: #{total}/#{success} (#{sprintf '%2d%', (success/total.to_f)*100 rescue 'N/A'})", '-'*120

    puts "    PID      |     RSS      | %CPU | %MEM |   ELAPSED   | TOTAL/SUCCESS | RATIO |     ACCOUNT     | COMMAND"
    puts '='*120

    processes.each do |p|
      print p[:pid].center(12)                       + ' | ' +
            p[:rss].center(12)                       + ' | ' +
            p[:cpu].center(4)                        + ' | ' +
            p[:mem].center(4)                        + ' | ' +
            p[:etime].center(11)                     + ' | ' +
            "#{p[:total]}/#{p[:success]}".center(13) + ' | ' +
            p[:ratio].center(5)                      + ' | ' +
            p[:name].to_s[0..14].center(15)          + ' | ' +
            p[:command][0..10]
      print "\n"
    end
    puts '-'*120
  end

end
