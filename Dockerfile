FROM ruby:2.3

label maintainer="Hossam Hammady <github@hammady.net>"

WORKDIR /home
COPY / /home/
RUN bundle install && bundle exec rake install

ENTRYPOINT ["scaltainer"]

CMD ["-h"]
