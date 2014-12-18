# Slug compiler

## Overview

A slug is a unit of deployment which includes everything an
application needs to run. The slug compiler is a program which uses a
buildpack to transform application source into a slug, typically by
gathering all dependencies and compiling source to binaries, if
applicable.

As inputs it takes a source directory, cache directory, buildpack URL,
and output directory. It places a tarball of the slug as well as a
JSON file of process types in the output directory if compilation is
successful.

--Note that this is a trimmed down version of the slug compiler that
currently runs in production on Heroku. It's intended for next-gen
services but is not currently in production use.--

This implementation no longer matches Heroku's production implementation. The current implementation isn't suitable for standalone use like this gem is. There are currently no plans for Heroku to use this implementation or split out the current implementation.

## Usage

In the typical git-based Heroku deploy, the slug compiler is invoked
via a Git pre-recieve hook. However, this code has been extracted so
that the same process can be used elsewhere.

Note that it will delete .slugignore patterns and other files, so you
shouldn't run this straight out of a checkout. Create a fresh copy of
the application source before compiling it.

## Requirements

* Ruby 1.9
* tar
* du
* git (optional, used for fetching non-HTTP buildpacks)

## Responsibilities

The new slug compiler does much less than the old one. In particular,
these operations are now the responsibility of the caller:

* checking size of the slug
* stack migration
* detecting among set of default buildpacks
* git submodule handling
* special-cased bamboo operations
* calling releases API
* storing slug file in S3
* deploy hooks
