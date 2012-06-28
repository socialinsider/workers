# encoding: UTF-8

module Workers

  class WorkerProcess < Hash

    def self.count(group, pid_dir=Dir.pwd)
      pids  = pidfiles(group, pid_dir).map { |file| File.read(file).to_i }
      return 0 if pids.empty?
      ps_output = `COLUMNS=1000 && ps -o pid,%cpu,%mem,rss,etime,command -p #{pids.join(',')}`
      return 0 if ps_output =~ /^\s*$/
      ps_output.split("\n")[1..-1].size
    end

    def self.all(group, pid_dir=Dir.pwd)
      redis = Redis.new
      pids  = pidfiles(group, pid_dir).map { |file| File.read(file).to_i }
      # p pid_dir
      return [] if pids.empty?

      ps_output = `COLUMNS=1000 && ps -o pid,%cpu,%mem,rss,etime,command -p #{pids.join(',')}`
      # puts ps_output
      processes = ps_output.split("\n")[1..-1].map do |line|
        _, pid, cpu, mem, rss, etime, command = line.split(/
        ^\s*(\d+)\s+               # PID
            (\d{1,2}\.\d{1,2})\s+  # CPU
            (\d{1,2}\.\d{1,2})\s+  # MEM
            (\d+)\s+               # RSS
            (\S+)\s+               # ETIME
            (.*)                   # COMMAND
        /x)
        { pid: pid, cpu: cpu, mem: mem, rss: rss, etime: etime, command: command }
      end.reject { |p| p[:pid].nil? }

      processes.map do |p|
        p[:total]   = redis.get("#{group}:jobs:worker:#{p[:pid]}:total").to_i
        p[:success] = redis.get("#{group}:jobs:worker:#{p[:pid]}:success").to_i
        p[:ratio]   = (sprintf '%2d%', (p[:success]/p[:total].to_f)*100).to_s rescue 'N/A'
        p[:name]    = redis.get("#{group}:workers:worker:#{p[:pid]}")
        p
      end
    end

    def self.pidfiles(group, pid_dir=Dir.pwd)
      Dir["#{pid_dir}/#{group}/*.pid"]
    end

  end

end
