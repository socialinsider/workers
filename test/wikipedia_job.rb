# encoding: UTF-8

require File.expand_path('../../lib/workers', __FILE__)

Bundler.require :wikipedia_job

require 'tire/http/clients/curb'

ES_URL = ENV['WORKERS_ES_URL'] || 'http://localhost:9200'

class WikipediaJob
  def self.perform(payload={})
    puts "PERFORM: #{payload.inspect}..." if ENV['WORKERS_DEBUG'] == 'verbose'

    raise "...FAKING WIKIPEDIA SERVICE ERROR..." if rand(10) > 8

    Tire.configure do
      url    ES_URL
      client Tire::HTTP::Client::Curb
    end

    if page = RestClient.get('http://en.wikipedia.org/w/api.php?' +
                             'action=query&format=json&list=random&rnnamespace=0&rnlimit=1',
                             'User-Agent' => 'Example fetcher (ruby)')
      id   = MultiJson.decode(page)['query']['random'][0]['id'].to_s
      page = MultiJson.decode( RestClient.get("http://en.wikipedia.org/w/api.php?" +
                                              "action=query&prop=revisions&rvprop=content&format=json&pageids=#{id}",
                                              "User-Agent" => "Example fetcher (ruby)"))

      puts "Indexing page \e[1m“#{page['query']['pages'][id]['title']}\e[0m”..." if ENV['WORKERS_DEBUG']
      
      Tire.index 'test_workers_wikipedia' do
        store :id      => id,
              :title   => page['query']['pages'][id]['title'],
              :content => page['query']['pages'][id]['revisions'][0]['*']
      end

      sleep rand(10)
    end
  end
end
