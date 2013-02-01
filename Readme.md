# Slug compiler

## Overview

A slug is a compressed archive of an app's code, to be stored in S3
and subsequently fetched by runtime instances (the
[dyno grid](http://heroku.com/how/dyno_grid)) for execution of one of
the app's processes.

The slug compiler is a program which uses a buildpack to transform
application source into a slug.

Inputs: source, cache, buildpack URL, feature flags
Output: slug, process_types, config vars?

* Fetch buildpack
* Compile
* Apply slugignore/prune
* Adjust permissions
* Parse Procfile
* Tar
* Size checks (raw/slug/cache)

## Usage

On Heroku, the slug compiler is invoked via a Git pre-recieve hook. To
test locally, you can run `slugc` manually against your sample app's
Git repo.

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
