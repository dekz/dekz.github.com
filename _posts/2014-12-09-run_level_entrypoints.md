---
layout: post
title: Reusable Entrypoints with Run Levels
tags: docker ci
published: true
---

We recently finished migrating to our new CI platform :package:, many projects, many containers, a lot of layers.
Then we found ourselves repeating ourselves.

Each project copied one another and created similar files for their containers and projects.

Unfortunately this meant when one project got a sweet new upgrade, no one else benefited.

*Our containers were leaking!* To much of our CI environment was ending up in the projects themselves.

So we looked at addressing this and hopefully create an extensible system.

## Entrypoint

The scripts being duplicated were container [ENTRYPOINT](https://docs.docker.com/reference/builder/#entrypoint)'s. This is the place where we solved runtime problems such as creating a runtime user to execute the build.

Below are 3 tasks taken from our old entrypoint, these are required to be performed in order to get the container in a state to execute the build.

1. Download artefacts (assets)
2. Create a special user with a specific UID
3. Get gems :gem:

We then split these tasks into scripts and assigned each a run level. Then we took them out of each project and moved them as high up into the container level as possible.

Here are the containers alongside their scripts:

```
base:
  010_assets # Get assets (artefacts) from previous build step
  020_application_user # Execute as a specific user

ruby < base:
  110_bundler # Get gems and bundle install

node < base:
  110_npm # Install our node modules

2.1.2 < ruby:
1.9.3 < ruby:
```

The new entrypoint (aptly named `entrypoint_runner`) is now the default in all containers. It just walks through the list and executes the scripts in ascending fashion. Simples.

The numbers prepended to the names do have some significane. The most significant number (MSN) is related to the container, as you inherit you increase, second MSN is the usual column of increment, third MSN is for additional granularity.

## Re-usability

Since everything is now moved up as high as it can go, and co-exists with the container, each project do is free of this burden.

In our environment, getting gems involves an rsync from system into local vendor then a final bundle install (system can be out of date). This requires knowledge of a specific ruby version. Knowledge only available in a child container.

To make use of this, `110_bundler` uses an ENV variable (`RUBY_VERSION`), and our Ruby 2.1.2 container ensures this is set container. To set this, 2.1.2 injects a script `109_ruby_env`, which populates this. 109 gets executed before 110, `RUBY_VERSION` is set before bundler, the magic happens. That was the **hard** way.

The **easy** way is to declare a container ENV in fig.yml or the Dockerfile. :whale:

## Build Scripts

Our builds can only execute scripts, this enforces a 'no arbitrary commands’ policy. As a product of this, all build scripts live in VCS. In special (see: lazy) cases we call a generic ‘rake’ script. Eventually every project their own 'rake' script.

We take a similar approach as above and push these scripts into the container rather than a project by project basis.

Below is an example of what could be on a container:

```
/opt/hooroo-ci/scripts/rake

/opt/hooroo-ci/entrypoint_runner

/opt/hooroo-ci/entrypoints/010_assets
/opt/hooroo-ci/entrypoints/020_application_user
/opt/hooroo-ci/entrypoints/110_bundler
```

Here is a birds eye view of a build run:

```
--- setup environment
--- running hooroo-ci/scripts/rake (in Fig container 'app')
--- 005_copy_ci_scripts_into_place
--- 010_detect_local_or_BB_run
--- 020_assets
--- 030_set_up_user
--- 110_bundle_install
--- bundle exec rake assets:precompile default
```

## Batteries included, but removable

Don’t want any of that? Then simply override your entrypoint for the container.
