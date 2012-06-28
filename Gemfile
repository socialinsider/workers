source "http://rubygems.org"

# Specify your gem's dependencies in workers.gemspec
gemspec

# Load gems for workers
#
# Specify gem dependencies in your job Gemfile like this:
#
#     group :my_job_name do
#       gem 'curb'
#       gem ...
#     end
#
# Load the gems in your job class class like this:
#
#     Bundler.require(:my_job_name)
#
Dir['./**/Gemfile'].each do |gemfile|
  next if File.absolute_path(gemfile) == __FILE__
  # STDERR.puts "Loading gems from #{gemfile}"
  eval File.read(gemfile)
end
