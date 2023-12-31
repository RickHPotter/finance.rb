ARG RUBY_VERSION=3.3.0-bullseye
FROM ruby:$RUBY_VERSION

RUN apt-get update -qq && \
  apt-get install -y \
  build-essential \
  libvips \
  bash \
  bash-completion \
  libffi-dev \
  tzdata \
  postgresql \
  nodejs \
  npm \
  yarn && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

WORKDIR /rails
COPY . /rails/

ENV BUNDLE_PATH /gems
RUN bundle && bin/rails assets:clean assets:precompile env:setup
