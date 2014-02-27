Workers
=======

This repository provides the infrastructure for performing background tasks.

The `workers` provides the supporting DSL and Rake tasks for defining and launching workers.

The `test` directory contains a simple job definition and launcher script,
which periodically downloads a random page from _Wikipedia_ and stores it in an _elasticsearch_ index.

## Introduction and examples ##

The worker DSL is used to start and fork Ruby processes, which in turn call the job definition, passed
as a lambda. For example:

```ruby
    worker :my_group, { name: 'account-1', data: 'Quick Brown Fox' }, 60, lambda { |payload|
        puts "Number of words: #{payload[:data].split(/\W/).size}"
    end
```

This definition will launch a worker in the `my_group` group (used to identify worker groups, saving PID files, etc)
and every `60` seconds performs the `lambda`, passing it the `Hash` payload.

The DSL allows also to launch more workers in one script, taking a collection of payload Hashes. For example:


```ruby
    class Job
      def self.perform(payload={})
        puts "PERFORM: #{payload.inspect}..."
        puts "Number of words: #{payload[:data].split(/\W/).size}"
      end
    end

    accounts = [
      { name: 'one',   data: 'ABC'},
      { name: 'two',   data: 'DEF'},
      { name: 'three', data: 'GHI'}
    ]

    launch :my_group, accounts, 60, lambda { |payload|
      Job.perform(payload)
      sleep 5
    }
```

You may run this code in a custom script, or use the provided _Rake_ tasks.

To launch 3 concurrent workers, run this _Rake_ task in the main project directory:

    rake workers:start_all WORKERS_LAUNCHER=./test/launcher.rb \
                           WORKERS_PID_DIR=./test/tmp/pids \
                           WORKERS_MONITRC_DIR=./test/tmp/monit \
                           WORKERS_JOBPATH=./test/ \
                           WORKERS_GROUP=wikipedia_job \
                           WORKERS_HEARTBEAT=10

To stop these workers, run this _Rake_ task:

    rake workers:stop_all WORKERS_PID_DIR=./test/tmp/pids WORKERS_GROUP=wikipedia_job

To inspect workers status, run this Rake task:

    rake workers:stats WORKERS_PID_DIR=./test/tmp/pids WORKERS_GROUP=wikipedia_job

To launch a single worker, run this _Rake_ task in the main project directory:

    rake workers:start WORKERS_MONITRC_DIR=./test/tmp/monit \
                       WORKERS_PID_DIR=./test/tmp/pids/ \
                       WORKERS_JOB_PATH=./test/ \
                       WORKERS_JOBCLASS=WikipediaJob \
                       WORKERS_NAME=test \
                       WORKERS_HEARTBEAT=10 \
                       WORKERS_DEBUG=true

To stop this worker, run this Rake script:

    rake workers:stop WORKERS_PID_DIR=./test/tmp/pids WORKERS_NAME=test WORKERS_GROUP=wikipedia_job

## The Web GUI ##

The repository provides a _Sinatra_-based GUI to provide overview of running workers,
number of jobs they have processed, their status, etc. You can launch the application
with the following command:

    WORKERS_PID_DIR=./test/pids/ thin -R lib/workers/server/config.ru start

## Monitoring ##

The DSL creates a standalone configuration file for the [_Monit_](http://mmonit.com/monit/documentation/monit.html)
utility, which can be used to monitor and restart the worker process.


## Documentation ##

You may want to generate this documentation into `doc`, in a reader-friendly format,
with the following command:

    yardoc --private --protected --readme README.markdown --markup markdown

----

(c) 2014 Social Insider, s.r.o.
