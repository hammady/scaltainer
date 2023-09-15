![Build Status](https://github.com/hammady/scaltainer/actions/workflows/tests.yml/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/hammady/scaltainer/badge.svg?service=github&branch=master)](https://coveralls.io/github/hammady/scaltainer?branch=master)

# Scaltainer

A Ruby gem to monitor Docker Swarm mode services and Kubernetes resources
and auto-scale them based on user configuration.
It can be used to monitor web services and worker services. The web services type has metrics like response time using [New Relic](https://newrelic.com/). The worker services type metrics are basically the queue size for each.
This gem is inspired by [HireFire](https://manager.hirefire.io/) and was indeed motivated by the migration
from [Heroku](https://www.heroku.com/) to Docker.

## Installation

Add this line to your application's Gemfile:

Install using rubygems:

    $ gem install scaltainer

## Usage

For Docker swarm:

    bundle exec scaltainer -o swarm

Or simply:

    bundle exec scaltainer

For Kubernetes:

    bundle exec scaltainer -o kubernetes


This will do a one-time check on the running docker service replicas
or Kubernetes replication controllers, replica sets, or deployments.
Then it sends scaling out/in commands to the cluster as appropriate.
Configuration is read from `scaltainer.yml` by default. If you want to read from another file add `-f yourconfig.yml`:

    bundle exec scaltainer -f yourconfig.yml

Note that after each run a new file is created (`yourconfig.yml.state`) which stores the state of the previous run.
This is because there are some configuration parameters (like sensitivity) need to
remember previous runs.
If you want to specify a different location for the state file, add the `--state-file` parameter.
Example:

    bundle exec scaltainer -f /path/to/configuration/file.yml --state-file /path/to/different/state/file.yml

Typically one would want to repeatedly call scaltainer every minute or so. To do this
specify the wait time between repetitions using the `-w` parameter in seconds:

    bundle exec scaltainer -w 60

This will repeatedly call scaltainer every 60 seconds, sleeping in-between.

If you would like to monitor the changes in scaling out and in. You can install
Prometheus and add a configuration parameter pointing to its Push Gateway:

    bundle exec scaltainer -g prometheus-pushgateway.monitoring.svc.cluster.local:9091

Where `prometheus-pushgateway.monitoring.svc.cluster.local:9091` is the address
of the push gateway. For Kubernetes environments the above denotes the gateway service
name (`prometheus-pushgateway`), where it is installed in the namespace called
`monitoring`. Scaltainer will report the following metrics to Prometheus:

- `scaltainer_web_replicas_total`: number of web replicas scaled (or untouched thereof).
This is labeled by the namespace and controller name, both matching the scaltainer
configuration file.
- `scaltainer_worker_replicas_total`: Same as above, but for workers
- `scaltainer_web_response_time_seconds`: response times as reported by the web services
- `scaltainer_worker_queue_size_total`: queue sizes as reported by the worker services
- `scaltainer_ticks_total`: iterations scaltainer has performed (if `-w` is used)

If you prefer to use New Relic monitoring, replace the `-g` parameter with `--enable-newrelic-reporting`.
If enabled, must set the environment variables `NEW_RELIC_LICENSE_KEY` and `NEW_RELIC_APP_NAME` (see below).
Once enabled, the below will be reported:

- `Custom/WebReplicas/service`
- `Custom/WorkerReplicas/service`
- `Custom/WebMetric/service`
- `Custom/WorkerMetric/service`
- `Custom/Scaltainer/ticks`

Where `service` is a placeholder for each service defined in `yourconfig.yml`.

Here is an example NRQL to query the metrics:

```
FROM Metric
SELECT max(newrelic.timeslice.value)
WHERE appName = 'YOUR APP NAME'
WITH METRIC_FORMAT 'Custom/WebReplicas/{web}'
FACET web
SINCE 1 day ago TIMESERIES MAX
```

## Configuration

### Environment variables

#### Docker swarm options

- `DOCKER_URL`: Should point to the docker engine URL.
If not set, it defaults to local unix socket.

#### Kubernetes options

- `KUBECONFIG`: set to Kubernetes config
(default: `$HOME/.kube/config`) if you want to connect
to the current configured cluster.

- `KUBERNETES_API_SERVER`: overrides option in `KUBECONFIG`
and defaults to `https://kubernetes.default:443`.

- `KUBERNETES_SKIP_SSL_VERIFY`: `KUBECONFIG` option overrides
this, set to any value to skip SSL verification.

- `KUBERNETES_API_ENDPOINT`: defaults to `/api`.

- `KUBERNETES_API_VERSION`: overrides option in `KUBECONFIG`
and defaults to `v1`.

- `KUBERNETES_CONTROLLER_KIND`: controller kind to scale,
allowed values: `deployment` (default),
`replication_controller`, or `replica_set`.

Make sure the `KUBERNETES_CONTROLLER_KIND` you specify is
part of the api specified using `KUBERNETES_API_ENDPOINT`
and `KUBERNETES_API_VERSION`.

#### General options

- `HIREFIRE_TOKEN`: If your application is configured the
[hirefire](https://help.hirefire.io/guides/hirefire/job-queue-any-programming-language) way, you need to
set `HIREFIRE_TOKEN` environment variable before invoking
`scaltainer`. This is used when probing your application
endpoint (see below) to get the number of jobs per queue
for each worker.

- `NEW_RELIC_API_KEY`: New Relic API key. Currently New Relic
is used to retrieve average response time metric for web services.
More monitoring services can be added in the future.

- `RESPONSE_TIME_WINDOW`: Time window in minutes to measure
average response time till the moment. For example 3 means
measure average response time in the past 3 minutes. Default value is 5.

- `LOG_LEVEL`: Accepted values here are: `DEBUG`, `INFO` (default), `WARN`, `ERROR`, `FATAL`.
Log output goes to stdout.

- `DOCKER_SECRETS_PATH_GLOB`: Path glob containing environment files to load.
This is useful if running from a docker swarm mode environment where one or more of the above
environment variables are set using `docker config` or `docker secret`.
These files should be in the form `VARIABLE=value`.
A typical value of this variable would be: `{/run/secrets/*,/config1,/config2}`

- `NEW_RELIC_LICENSE_KEY`: New Relic license key, required if `--enable_newrelic_reporting`
is used.
- `NEW_RELIC_APP_NAME`: New Relic application name, required if `--enable_newrelic_reporting`
is used.
### Configuration file

The configuration file (determined by `-f FILE` command line parameter) should be in the following form:

    # to get worker metrics
    endpoint: https://your-app.com/hirefire/$HIREFIRE_TOKEN/info
    # optional docker swarm stack name or kubernetes namespace (useful if having push gateway)
    namespace: mynamespace
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

## Docker Swarm usage

A service definition for scaltainer is typically something like this:

    version: '3.3'
    services:
      scaltainer:
        image: rayyanqcri/scaltainer:latest
        command: -f /scaltainer.yml --state-file /tmp/scaltainer-state.yml -w 60
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
        environment:
          - DOCKER_URL=unix:///var/run/docker.sock
          - DOCKER_SECRETS_PATH_GLOB={/run/secrets/*}
          - RESPONSE_TIME_WINDOW=3
        configs:
          - source: scaltainer
            target: /scaltainer.yml
        secrets:
          - scaltainer
        deploy:
          replicas: 1
          placement:
            constraints:
              - node.role == manager
    configs:
      scaltainer:
        file: scaltainer.yml
    secrets:
      scaltainer:
        file: scaltainer.env

Where `scaltainer.env` is a file containing HireFire and NewRelic secrets:

    HIREFIRE_TOKEN=
    NEW_RELIC_API_KEY=

And `scaltainer.yml` is the scaltainer configuration file.

## Kubernetes usage

### Create a ConfigMap

    kubectl create configmap scaltainer --from-file=scaltainer.yaml=/path/to/your/scaltainer.yml

Where `/path/to/your/scaltainer.yml` is the scaltainer configuration file.

### Create a Secret

    kubectl create secret generic scaltainer --from-env-file=/path/to/scaltainer.env

Where `/path/to/scaltainer.env` is a file containing HireFire and NewRelic secrets:

    HIREFIRE_TOKEN=
    NEW_RELIC_API_KEY=

### Create a Deployment:

    kubectl apply -f scaltainer-kube.yaml

Where scaltainer-kube.yaml has the following content:

    apiVersion: extensions/v1beta1
    kind: Deployment
    metadata:
      labels:
        app: scaltainer
      name: scaltainer
    spec:
      replicas: 1
      template:
        metadata:
          labels:
            app: scaltainer
        spec:
          containers:
          - image: rayyanqcri/scaltainer:latest
            name: scaltainer
            args:
              - -o
              - kubernetes
              - -f
              - /etc/config/scaltainer.yaml
              - --state-file
              - /tmp/scaltainer-state.yaml
              - -w
              - "60"
            env:
            - name: KUBERNETES_SKIP_SSL_VERIFY
              value: "yes"
            - name: KUBERNETES_API_ENDPOINT
              value: /apis/extensions
            - name: KUBERNETES_API_VERSION
              value: v1beta1
            - name: KUBERNETES_CONTROLLER_KIND
              value: deployment
            envFrom:
            - secretRef:
                name: scaltainer
            volumeMounts:
            - name: scaltainer-config
              mountPath: "/etc/config"
          volumes:
          - name: scaltainer-config
            configMap:
              name: scaltainer


## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hammady/scaltainer.

## Testing

    rake

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
