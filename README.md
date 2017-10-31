[![Build Status](https://travis-ci.org/hammady/scaltainer.svg?branch=master)](https://travis-ci.org/hammady/scaltainer)
[![Coverage Status](https://coveralls.io/repos/github/hammady/scaltainer/badge.svg?branch=master)](https://coveralls.io/github/hammady/scaltainer?branch=master)

# Scaltainer

A Ruby gem to monitor docker swarm mode services and auto-scale them based on user configuration.
It can be used to monitor web services and worker services. The web services type has metrics like response time using [New Relic](https://newrelic.com/). The worker services type metrics are basically the queue size for each.
This gem is inspired by [HireFire](https://manager.hirefire.io/) and was indeed motivated by the migration
from [Heroku](https://www.heroku.com/) to Docker Swarm mode.

## Installation (not published yet to rubygems)

Add this line to your application's Gemfile:

```ruby
gem 'scaltainer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install scaltainer

## Usage

    scaltainer

This will do a one-time check on the running service replicas and sends scaling out/in commands to the swarm cluster as appropriate.
Configuration is read from `scaltainer.yml` by default. If you want to read from another file add `-f yourconfig.yml`:

    scaltainer -f yourconfig.yml

Note that after each run a new file is created (`yourconfig.yml.state`) which stores the state of the previous run.
This is because there are some configuration parameters (like sensitivity) need to
remember previous runs.

Typically, the above command should be put inside a cronjob that is triggered every minute or so.

## Configuration

### Environment variables

- `DOCKER_URL`: Should point to the docker engine URL.
If not set, it defaults to local unix socket.

- `HIREFIRE_TOKEN`: If your application is configured the
[hirefire](https://help.hirefire.io/guides/hirefire/job-queue-any-programming-language) way, you need to
set `HIREFIRE_TOKEN` environment variable before invoking
`scaltainer`. This is used when probing your application
endpoint (see below) to get the number of jobs per queue
for each worker.

- `NEW_RELIC_LICENSE_KEY`: New Relic license key. Currently New Relic
is used to retrieve average response time metric for web services.
More monitoring services can be added in the future.
- `RESPONSE_TIME_WINDOW`: Time window in minutes to measure
average response time till the moment. For example 3 means
measure average response time in the past 3 minutes. Default value is 5.

- `LOG_LEVEL`: Accepted values here are: `DEBUG`, `INFO` (default), `WARN`, `ERROR`, `FATAL`.
Log output goes to stdout.

### Configuration file

The configuration file (determined by `-f FILE` command line parameter) should be in the following form:

    # to get worker metrics
    endpoint: https://your-app.com/hirefire/$HIREFIRE_TOKEN/info
    # optional docker swarm stack name
    stack_name: mystack
    # list of web services to monitor
    web_services:
      # each service name should match docker service name
      web:
        # New Relic application id (required)
        newrelic_app_id: <app_id>
        # minimum replicas to maintain (default: 0)
        min: 1
        # maximum replicas to maintain (default: unlimited)
        max: 5
        # maximum response time above which to scale up (required)
        max_response_time: 300
        # minimum response time below which to scale down (required)
        min_response_time: 100
        # replica quantitiy to scale up at a time (default: 1)
        upscale_quantity: 2
        # replica quantitiy to scale down at a time (default: 1)
        downscale_quantity: 1
        # number of breaches to wait for before scaling up (default: 1)
        upscale_sensitivity: 1
        # number of breaches to wait for before scaling down (default: 1)
        downscale_sensitivity: 1
      webapi:
        ...
    worker_services:
      worker1:
        min: 1
        max: 10
        # number of jobs each worker replica should process (required)
        # the bigger the ratio, the less number of workers scaled out
        ratio: 3
        upscale_sensitivity: 1
        downscale_sensitivity: 1
      worker2:
        ...

More details about configuration parameters can be found in [HireFire docs](https://help.hirefire.io/guides).

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hammady/scaltainer.

## TODOs

- Rspec

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
