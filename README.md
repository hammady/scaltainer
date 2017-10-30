# Scaltainer

A Ruby gem to monitor docker swarm mode services and auto-scale them based on user configuration.
It can be used to monitor web services and worker services. The web services type has metrics like response time
optionally with [New Relic](https://newrelic.com/) support. The worker services type metrics are basically the queue size for each.
This gem is inspired by [HireFire](https://manager.hirefire.io/) and was indeed motivated by the migration
from [Heroku](https://www.heroku.com/) to Docker Swarm mode.

## Installation

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

Details of configuration parameters can be found in [HireFire docs](https://help.hirefire.io/guides).
Set the environment variable `DOCKER_URL` to point to the docker engine URL.
If not set, it defaults to local unix socket.

If your application is configured the
[hirefire](https://help.hirefire.io/guides/hirefire/job-queue-any-programming-language) way, you need to
set `HIREFIRE_TOKEN` environment variable before invoking
`scaltainer`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hammady/scaltainer.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
