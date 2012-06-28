This directory contains a simple, example worker class definition: `wikipedia_job.rb`,
and a simple, example launcher script: `launcher.rb` to test the infrastructure.

Launch multiple workers with the following command:

    rake workers:start_all WORKERS_LAUNCHER=test/launcher.rb \
                           WORKERS_HEARTBEAT=10              \
                           WORKERS_GROUP=WikipediaJob        \
                           WORKERS_DEBUG=true

See the main project README for more information.
