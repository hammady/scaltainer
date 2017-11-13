FROM ruby:2.3

MAINTAINER Hossam Hammady <github@hammady.net>

RUN gem install scaltainer

ENTRYPOINT ["scaltainer"]

CMD ["-h"]
