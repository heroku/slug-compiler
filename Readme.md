# Slug compiler

## Overview

A slug is a compressed archive of an app's code, to be stored in S3
and subsequently fetched by runtime instances (the
[dyno grid](http://heroku.com/how/dyno_grid)) for execution of one of
the app's processes.

The slug compiler is a program which uses a buildpack to transform
application source into a slug.

Inputs: source, cache, buildpack URL, feature flags?

Output: slug, process_types, config vars?

Note that this is a trimmed down version of the slug compiler that
currently runs in production on Heroku. It's intended for next-gen
services but is not currently in production use.

## Usage

In the typical git-based Heroku deploy, the slug compiler is invoked
via a Git pre-recieve hook. However, this code has been extracted so
that the same process can be used elsewhere.

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
