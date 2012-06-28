require 'rack/websocket'
require 'em-hiredis'

class WebsocketApp < Rack::WebSocket::Application

  def initialize
    EM.next_tick do
      @redis = EM::Hiredis.connect
    end
  end

  def on_open(env)
    @redis.subscribe("channels:fetchers")

    @redis.on(:message) do |channel, message|
      # p [:message, channel, message]
      send_data message
    end
  end
end
