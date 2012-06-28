# encoding: UTF-8

require 'sinatra'
require 'json'
require 'erubis'
require 'redis'
require 'workers'

module Workers

  class Application < Sinatra::Base
    USERNAME = ENV['WORKERS_USERNAME']
    PASSWORD = ENV['WORKERS_PASSWORD']

    enable :logging, :static

    use( Rack::Auth::Basic, "Workers Status") do |username, password|
      [username, password] == [USERNAME,PASSWORD]
    end

    helpers do
      def redis
        @__redis ||= Redis.new
      end

      def ratio_to_class(ratio)
        case ratio.to_i
        when 90..100
          'high'
        when 70..90
          'mid'
        when 0..70
          'low'
        end
      end

      def stats
        @total           = redis.get("#{@group}:jobs:total").to_i
        @success         = redis.get("#{@group}:jobs:success").to_i
        @ratio           = (sprintf '%2d%', (@success/@total.to_f)*100).to_s rescue 'N/A'
        @num_pidfiles    = Workers::WorkerProcess.pidfiles(@group, ENV['WORKERS_PID_DIR']).size
        @num_processes   = Workers::WorkerProcess.count(@group, ENV['WORKERS_PID_DIR'])
        @num_missing     = ( @num_pidfiles - @num_processes rescue 0 )
      end
    end

    after '/ws|/groups/*' do
      stats
    end

    get '/' do
      @groups = Dir.entries(ENV['WORKERS_PID_DIR']).reject { |d| d =~ /^\./ }
      erb :index
    end

    get '/groups/:group' do |group|
      @group     = group
      stats
      @processes = Workers::WorkerProcess.all(group, ENV['WORKERS_PID_DIR'])
      erb :group
    end

    get '/stats/:group' do |group|
      @group = group
      stats
      {
        total:    @total,
        success:  @success,
        ratio:    @ratio,
        ratio_css_class: ratio_to_class(@ratio),
        num_pidfiles:    @num_pidfiles,
        num_processes:   @num_processes,
        num_missing:     @num_missing
      }.to_json
    end

  end

end
