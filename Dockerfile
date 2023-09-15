FROM ruby:2.7

LABEL maintainer="Hossam Hammady <github@hammady.net>"

ENV NEW_RELIC_LOG=stdout
ENV NEW_RELIC_AUTOSTART_DENYLISTED_CONSTANTS=Scaltainer

RUN gem install bundler --version 2.2.19

WORKDIR /home
COPY / /home/
RUN bundle install && bundle exec rake install

ENTRYPOINT ["bundle", "exec", "scaltainer"]

CMD ["-h"]
