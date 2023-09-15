#!/usr/bin/env bash
if [ ! -z "$RUBYGEMS_API_KEY" ]; then
  mkdir $HOME/.gem
  creds="$HOME/.gem/credentials"
  echo -e "---\n:rubygems_api_key: $RUBYGEMS_API_KEY" > $creds
  chmod 0600 $creds
fi

gem build scaltainer.gemspec
gem push scaltainer*.gem
