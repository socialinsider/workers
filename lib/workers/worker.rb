# encoding: UTF-8

module Workers

  module Worker

    # Forks a new process running the worker code
    #
    # The process is daemonized after forking.
    # The statistics about the worker are saved into Redis under the <group> name.
    # The process PID is saved as a file into <WORKERS_PID_DIR>/<group> and into Redis' list.
    # Every <heartbeat> seconds, forks another process, which runs the
    # Ruby code passed as the <block> argument.
    #
    # Example usage:
    # -------------
    #
    #     worker :my_group, { name: 'account-1', data: 'Quick Brown Fox' }, 60, lambda { |payload|
    #         puts "Number of words: #{payload[:data].split(/\W/).size}"
    #     end
    #
    def worker group, item, heartbeat, block
      FileUtils.mkdir_p File.join(ENV['WORKERS_PID_DIR'], group)

      name = item[:name] || item ['name'] || item.to_s rescue item.to_s

      __redis = Redis.new

      __procline = lambda { |string| $0=string }

      __log = lambda { |*args| puts *args }

      __create_worker_pid_file = lambda { |name, pid|
        Process.wait( Process.fork { exec "echo #{pid} > #{ENV['WORKERS_PID_DIR']}/#{group}/#{name}.pid"; exit! } )
      }

      __remove_worker_pid_file = lambda { |name|
        Process.wait( Process.fork { File.delete  "#{ENV['WORKERS_PID_DIR']}/#{group}/#{name}.pid"; exit! } )
      }

      # [master]
      #
      if pid = Process.fork
        __create_worker_pid_file.(name, pid)
        __redis.lpush "#{group}:workers:workers", pid
        __redis.set   "#{group}:workers:worker:#{pid}", name

      # [worker]
      #
      else
        __log.("[worker] #{name} (#{group}) starting... [pid: #{Process.pid}] [parent: #{Process.ppid}] [#{Time.now}]", "")
        __procline.("[worker] name: #{name} [#{Time.now}]")

        at_exit do
          __log.("[worker] #{name} exiting...")
          __remove_worker_pid_file.(name)
          __redis.lrem "#{group}:workers:workers", 1, Process.pid
          __redis.del  "#{group}:workers:worker:#{Process.pid}"
          __redis.del  "#{group}:jobs:worker:#{Process.pid}:total"
          __redis.del  "#{group}:jobs:worker:#{Process.pid}:success"

          __redis.smembers("#{group}:workers:worker:#{Process.pid}:children").each do |child_pid|
            Process.kill('INT', child_pid.to_i) rescue nil

            # Just to be sure because `block.call(item)` in [fetcher] can call `exit!`, so `at_exit` in [fetcher] wouldn't be called
            #
            __redis.srem("#{group}:workers:worker:#{Process.pid}:children", child_pid)
          end
          __redis.del "#{group}:workers:worker:#{Process.pid}:children"

          exit!
        end

        [:INT, :TERM].each do |signal|
          trap(signal) { exit }
        end

        loop do
          # [worker]
          #
          if pid = Process.fork
            Process.wait(pid)

          # [fetcher]
          #
          else
            at_exit do
              __log.("[fetcher] #{Process.pid} exiting...")
              __redis.srem("#{group}:workers:worker:#{Process.ppid}:children", Process.pid)

              exit!
            end

            [:INT, :TERM].each do |signal|
              trap(signal) { exit }
            end

            __log.("[fetcher] for '#{name}' forked... [pid: #{Process.pid}] [worker: #{Process.ppid}] [#{Time.now}]")
            __procline.("[fetcher] worker: #{Process.ppid} [#{Time.now}]")
            __redis.publish "channels:fetchers", Process.ppid
            __redis.incr    "#{group}:jobs:total"
            __redis.incr    "#{group}:jobs:worker:#{Process.ppid}:total"
            __redis.incr    "#{group}:jobs:accounts:#{name}:total"
            __redis.sadd    "#{group}:workers:worker:#{Process.ppid}:children", Process.pid

            block.call(item)

            __redis.incr "#{group}:jobs:success"
            __redis.incr "#{group}:jobs:worker:#{Process.ppid}:success"
            __redis.incr "#{group}:jobs:accounts:#{name}:success"
            __redis.srem "#{group}:workers:worker:#{Process.ppid}:children", Process.pid

            exit
          end

          sleep heartbeat
        end
        Process.daemon('nochdir', 'noclose')
      end
    end

    # Launch new worker in the <group> group for every item in the passed <collection>,
    # and perform the passed <block> in a forked process every <heartbeat>seconds.
    #
    # Example usage:
    # -------------
    #
    #     class Job
    #       def self.perform(payload={})
    #         puts "PERFORM: #{payload.inspect}..."
    #         puts "Number of words: #{payload[:data].split(/\W/).size}"
    #       end
    #     end
    #
    #     accounts = [
    #       { name: 'one',   data: 'ABC'},
    #       { name: 'two',   data: 'DEF'},
    #       { name: 'three', data: 'GHI'}
    #     ]
    #
    #     launch :my_group, accounts, 60, lambda { |payload|
    #       Job.perform(payload)
    #       sleep 5
    #     }
    #
    def launch group, collection, heartbeat, block
      collection.each do |item|
        Workers::Worker.worker  group.to_s, item, heartbeat.to_i, block
        Workers::Worker.monitrc group.to_s, item, heartbeat.to_i
        sleep (ENV["LAUNCHER_SLEEP"] || (heartbeat.to_i*3)/collection.size.to_f).to_i
      end
    end

    extend self
    extend Monitrc

  end

end
