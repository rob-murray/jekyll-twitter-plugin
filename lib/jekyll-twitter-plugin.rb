require 'twitter'

##
# A Liquid tag plugin for Jekyll that renders Tweets from Twitter API.
# https://github.com/rob-murray/jekyll-twitter-plugin
#
module TwitterJekyll
  class FileCache
    def initialize(path)
      @cache_folder   = File.expand_path path
      FileUtils.mkdir_p @cache_folder
    end

    def read(key)
      file_to_read = cache_file(cache_filename(key))
      JSON.parse(File.read(file_to_read)) if File.exist?(file_to_read)
    end

    def write(key, data)
      file_to_write = cache_file(cache_filename(key))
      data_to_write = JSON.generate data.to_h

      File.open(file_to_write, 'w') do |f|
        f.write(data_to_write)
      end
    end

    private

    def cache_file(filename)
      File.join(@cache_folder, filename)
    end

    def cache_filename(cache_key)
      "#{cache_key}.cache"
    end
  end

  class NullCache
    def read(_key); end

    def write(_key, _data); end
  end

  module Cacheable
    def cache_key
      Digest::MD5.hexdigest("#{self.class.name}-#{key}")
    end

    def key; end
  end

  class TwitterApi
    def initialize(client, params)
      @client = client
      @status_url = params.shift
      parse_args(params)
    end

    private

    def id_from_status_url(url)
      if url.to_s =~ /([^\/]+$)/
        Regexp.last_match[1]
      end
    end

    def find_tweet(id)
      return unless id

      @client.status(id.to_i)
    rescue Twitter::Error::NotFound
      nil
    end

    def parse_args(args)
      @params ||= begin
        params = {}
        args.each do |arg|
          k, v = arg.split('=').map(&:strip)
          if k && v
            if v =~ /^'(.*)'$/
              v = Regexp.last_match[1]
            end
            params[k] = v
          end
        end
        params
      end
    end
  end

  class Oembed < TwitterApi
    include TwitterJekyll::Cacheable

    def fetch
      tweet_id = id_from_status_url(@status_url)

      if tweet = find_tweet(tweet_id)
        @client.oembed tweet, @params
      end
    end

    private

    def key
      @status_url
    end
  end

  class UnknownTypeClient
    include TwitterJekyll::Cacheable

    def fetch; end
  end

  class TwitterTag < Liquid::Tag
    ERROR_BODY_TEXT = 'Tweet could not be processed'

    def initialize(_name, params, _tokens)
      super
      @cache    = FileCache.new('./.tweet-cache')
      args      = params.split(/\s+/).map(&:strip)
      @api_type = args.shift
      @params   = args

      create_twitter_rest_client
    end

    def render(_context)
      api_client = create_api_client(@api_type, @params)
      response = cached_response(api_client) || live_response(api_client)
      html_output_for(response)
    end

    private

    def html_output_for(response)
      body = ERROR_BODY_TEXT

      if response
        body = response.html || body
      end

      "<div class='embed twitter'>#{body}</div>"
    end

    def live_response(api_client)
      if response = api_client.fetch
        @cache.write(api_client.cache_key, response)
        response
      end
    end

    def cached_response(api_client)
      response = @cache.read(api_client.cache_key)
      OpenStruct.new(response) unless response.nil?
    end

    def create_api_client(api_type, params)
      klass_name = api_type.capitalize
      if TwitterJekyll.const_defined?(klass_name)
        api_client_klass = TwitterJekyll.const_get(klass_name)
        api_client_klass.new(@twitter_client, params)
      else
        UnknownTypeClient.new
      end
    end

    def create_twitter_rest_client
      @twitter_client = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV.fetch('TWITTER_CONSUMER_KEY')
        config.consumer_secret     = ENV.fetch('TWITTER_CONSUMER_SECRET')
        config.access_token        = ENV.fetch('TWITTER_ACCESS_TOKEN')
        config.access_token_secret = ENV.fetch('TWITTER_ACCESS_TOKEN_SECRET')
      end
    end
  end

  class TwitterTagNoCache < TwitterTag
    def initialize(_tag_name, _text, _token)
      super
      @cache = NullCache.new
    end
  end
end

Liquid::Template.register_tag('twitter', TwitterJekyll::TwitterTag)
Liquid::Template.register_tag('twitternocache', TwitterJekyll::TwitterTagNoCache)
