# Run me with:
#
#     $ WORKERS_PID_DIR=./test/pids/ thin -R lib/workers/server/config.ru start

$LOAD_PATH.unshift File.expand_path('../../../', __FILE__)

require File.expand_path('../application',  __FILE__)
require File.expand_path('../websocketapp', __FILE__)

map '/' do
  run Workers::Application
end

map '/ws' do
  run WebsocketApp.new
end
