## jekyll-twitter-plugin

A Liquid tag plugin for Jekyll that renders Tweets from Twitter API.

[![Gem Version](https://badge.fury.io/rb/jekyll-twitter-plugin.svg)](http://badge.fury.io/rb/jekyll-twitter-plugin)

### Description

A Liquid tag plugin for [Jekyll](http://jekyllrb.com/) that renders Tweets from Twitter API.

It is based on the original Jekyll Tweet Tag from [scottwb](https://github.com/scottwb/jekyll-tweet-tag) which has not been updated since Twitter updated their API to require Oauth. 

This plugin replaces the broken plugin mentioned above and uses a different tag and API just in case the original gets fixed and to be more flexible.


### Features

The plugin supports the following features from the Twitter API:

* Oembed - Embed a Tweet in familiar Twitter styling.
* Caching - API requests can be cached to avoid hitting request limits.


### Requirements

* You have set up a Twitter application and have auth credentials.


### Usage

As mentioned by [Jekyll's documentation](http://jekyllrb.com/docs/plugins/#installing-a-plugin) you have two options; manually import the source file or require the plugin as a `gem`.

#### Require gem

Add the `jekyll-twitter-plugin` to your site `_config.yml` file for Jekyll to import the plugin as a gem.

```ruby
gems: [jekyll-twitter-plugin]
```

#### Manual import

Just download the source file into your `_plugins` directory, e.g.

TODO

#### Plugin tag usage

To use the plugin, in your source content use the tag `twitter` and then pass additional parameters to the plugin.

```ruby
{% twitter type params %}
```

##### type

This is the type of Twitter API 

#### Oembed

{% twitter oembed url %}

##### Output

As with the original plugin, all content will be rendered inside a div with the classes 'embed' and 'twitter' 

```
<div class='embed twitter'>
    content
</div>
```

#### Output

If the request cannot be processed then a basic error message will be displayed;

> Tweet could not be processed


### Caching

TODO


### Contributions

Please use the GitHub pull-request mechanism to submit contributions.

### License

This project is available for use under the MIT software license.
See LICENSE
