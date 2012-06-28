# encoding: UTF-8

# See README for documentation

$LOAD_PATH.unshift File.expand_path('..', __FILE__)
require 'wikipedia_job'

accounts = [
  { name: 'one',   data: 'ABC'},
  { name: 'two',   data: 'DEF'},
  { name: 'three', data: 'GHI'}
]

COUNT = (ENV['WORKERS_COUNT'] || 3).to_i
accounts = (1..COUNT).to_a.map { |i| sprintf('%03d', i) }

Workers::launch :wikipedia_job, accounts, ENV['WORKERS_HEARTBEAT'].to_i, lambda { |payload|
  WikipediaJob.perform(payload)
}
