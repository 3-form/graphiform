# syntax=docker/dockerfile:1.7

ARG RUBY_VERSION=3.3.6
FROM ruby:${RUBY_VERSION}-slim-bookworm

ARG APPRAISAL=rails-8.1

ENV BUNDLE_GEMFILE=/app/gemfiles/${APPRAISAL}.gemfile \
    BUNDLE_PATH=/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_DISABLE_SHARED_GEMS=true \
    LANG=C.UTF-8 \
    RAILS_ENV=test

# System deps: build toolchain for native gems (sqlite3, nio4r, etc.),
# sqlite3 CLI for debugging, git for bundler git sources, tzdata for AR.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        libsqlite3-dev \
        libyaml-dev \
        sqlite3 \
        tzdata && \
    rm -rf /var/lib/apt/lists/*

RUN gem install bundler --no-document

WORKDIR /app

# Copy only files needed for bundle install first, for layer caching.
# We copy the whole gemfiles/ dir because appraisal generates lockfiles there.
COPY graphiform.gemspec Gemfile Gemfile.lock* ./
COPY gemfiles/ ./gemfiles/
COPY lib/graphiform/version.rb ./lib/graphiform/version.rb
RUN bundle install

# Default to running the test suite for the chosen appraisal.
CMD ["bundle", "exec", "rake", "test"]