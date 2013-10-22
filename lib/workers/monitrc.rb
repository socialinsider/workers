module Workers

  module Monitrc

    # Creates configuration file for Monit [http://mmonit.com/monit/documentation/monit.html]
    #
    # The method creates the folder for config files, if missing.
    #
    # The method creates a config file for worker for Monit, containing PID file location
    # and start/stop scripts.
    #
    # It depends on following environment variables:
    #
    # * WORKERS_MONITRC_DIR -- Path to Monit configuration files for include, eg. /etc/monit/conf.d/
    # * WORKERS_PID_DIR     -- Path to directory with worker PID files
    # * WORKERS_APP_DIR     -- Path to the application root, containing the Rakefile with start/stop tasks
    #
    # Example usage:
    # -------------
    #
    #     monitrc :my_group, { name: 'account-1' }
    #
    def monitrc group, item, heartbeat
      conf_dir = Pathname( ENV['WORKERS_MONITRC_DIR'] || File.join(Dir.pwd, 'monit', 'conf.d' )).join(group)
      pid_dir  = Pathname( ENV['WORKERS_PID_DIR']     || File.join(Dir.pwd, 'pids'    )).join(group)
      app_dir  = Pathname( ENV['WORKERS_APP_DIR']     || Dir.pwd                       )
      name     = item[:name] || item['name']  || item.to_s rescue item.to_s
      pidfile  = File.absolute_path(pid_dir.join("#{name}.pid").to_s)
      FileUtils.mkdir_p conf_dir

      environment_variables = ENV.keys.select { |key| key.to_s =~ /^WORKERS_/ }.inject([]) do |collection,key|
        collection << "#{key}=#{ENV[key]}"
      end.join(' ')
      template =<<-TEMPLATE.gsub(/          /, '')
        check process worker-#{group}-#{name} with pidfile #{pidfile}
          #{ "every #{heartbeat.to_i/60} cycles" if heartbeat.to_i > 59 }
          start program = "/bin/su - application -c 'source /etc/profile.d/rbenv.sh && cd #{app_dir} && bundle exec rake workers:start WORKERS_NAME=#{name} #{environment_variables} > #{app_dir}/log/#{group.downcase}-#{name.downcase}.log'" with timeout 10 seconds
          stop program  = "/bin/bash -c 'kill $(cat #{pidfile})'"
          group workers-#{group}
        
      TEMPLATE

      File.open(conf_dir.join("#{name}.monitrc"), 'w') { |f| f << template }
    end

  end

end
