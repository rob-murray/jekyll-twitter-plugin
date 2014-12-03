## jekyll-twitter-plugin

A Liquid tag plugin for Jekyll that renders Tweets from Twitter API.

[![Gem Version](https://badge.fury.io/rb/jekyll-twitter-plugin.svg)](http://badge.fury.io/rb/jekyll-twitter-plugin)


### Description

A Liquid tag plugin for [Jekyll](http://jekyllrb.com/) that enables Twitter content to be used in any content served by Jekyll, content is fetched from the [Twitter API](https://dev.twitter.com/home).

It is based on the original Jekyll Tweet Tag from [scottwb](https://github.com/scottwb/jekyll-tweet-tag) which has not been updated since Twitter updated their API to require certain preconditions. This version uses the excellent [Twitter gem](https://github.com/sferik/twitter) to make requests and handle authentication.

This plugin replaces the broken plugin mentioned above and uses a different tag name and API - this is by design so that the two plugins can be used, if the original gets fixed.


### Features

The plugin supports the following features:

* Installed via Rubygems
* [Oembed](#oembed) - Embed a Tweet in familiar Twitter styling.
* [Caching](#caching) - Twitter API responses can be cached to avoid hitting request limits.


### Requirements

* Twitter oauth credentials - Most Twitter api functions now require authentication. Set up your [application](https://dev.twitter.com/apps/new) and get the credentials.


### Usage

As mentioned by [Jekyll's documentation](http://jekyllrb.com/docs/plugins/#installing-a-plugin) you have two options; manually import the source file or require the plugin as a `gem`.

#### Require gem

Install the gem, add it to your Gemfile;

```ruby
gem 'jekyll-twitter-plugin'
```

Add the `jekyll-twitter-plugin` to your site `_config.yml` file for Jekyll to import the plugin as a gem.

```ruby
gems: ['jekyll-twitter-plugin']
```

#### Manual import

Just download the source file into your `_plugins` directory, e.g.

```bash
# Create the _plugins dir if needed and download project_version_tag plugin
$ mkdir -p _plugins && cd _plugins
$ wget https://raw.githubusercontent.com/rob-murray/jekyll-twitter-plugin/master/lib/jekyll-twitter-plugin.rb
```

#### Credentials

Your Twitter application authentication credentials are private - do not distribute these! As such this plugin requires your credentials as Environment variables, it requires the following keys to be set;

* TWITTER_CONSUMER_KEY
* TWITTER_CONSUMER_SECRET
* TWITTER_ACCESS_TOKEN
* TWITTER_ACCESS_TOKEN_SECRET

```bash
$ export TWITTER_CONSUMER_KEY=foo etc.
```

#### Plugin tag usage

To use the plugin, in your source content use the tag `twitter` and then pass additional parameters to the plugin.

```liquid
{% plugin_type api_type *params %}
```

* `plugin_type` - Either `twitter` or `twitternocache`.
* `api_type` - The Twitter API to use, check below for supported APIs.
* `*params` - Parameters for the API separated by spaces. Refer below and to respective Twitter API documentation for available parameters.

### Supported Twitter APIs

The following Twitter APIs are supported.

#### Oembed

The [oembed](https://dev.twitter.com/rest/reference/get/statuses/oembed) API returns html snippet to embed in your app, this will be rendered in the familiar Twitter style.

```liquid
{% twitter oembed status_url *options %}

# Example
{% twitter oembed https://twitter.com/rubygems/status/518821243320287232 %}
# With options
{% twitter oembed https://twitter.com/rubygems/status/518821243320287232 align='right' width='350' %}
```

### Output

As with the original plugin, all content will be rendered inside a div with the classes 'embed' and 'twitter' 

```html
<div class='embed twitter'>
    -- content --
</div>
```

If something goes wrong then a basic error message will be displayed;

> Tweet could not be processed


### Caching

TODO


### Contributions

I've tried hard to keep all classes and code in the one `lib/jekyll-twitter-plugin.rb` file so that people can just grab this file and include in their Jekyll `_plugins` directory if they do not want to use the Gem. This may have to be dropped if the one file gets too overwhelming.

Please use the GitHub pull-request mechanism to submit contributions.

### License

This project is available for use under the MIT software license.
See LICENSE
