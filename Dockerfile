FROM ruby:2.3

label maintainer="Hossam Hammady <github@hammady.net>"

ENV NEW_RELIC_LOG=stdout
ENV NEW_RELIC_AUTOSTART_DENYLISTED_CONSTANTS=Scaltainer

WORKDIR /home
COPY / /home/
RUN bundle install && bundle exec rake install

ENTRYPOINT ["scaltainer"]

CMD ["-h"]
