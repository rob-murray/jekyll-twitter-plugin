require 'twitter'

module TwitterJekyll
  class FileCache
    def initialize(path)
      @cache_folder   = File.expand_path path, File.dirname(__FILE__)
      FileUtils.mkdir_p @cache_folder
    end

    def read(key)
      file_to_read = cache_file(cache_filename(key))
      JSON.parse(File.read(file_to_read)) if File.exist?(file_to_read)
    end

    def write(key, data)
      file_to_write = cache_file(cache_filename(key))
      data_to_write = JSON.generate data.to_h

      File.open(file_to_write, "w") do |f|
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
    def initialize; end
    def read(_key); end
    def write(_key, _data); end
  end

  class Oembed
    def initialize(client, params)
      @client = client
      @params = params
    end

    def fetch
      if @params.to_s =~ /([^\/]+$)/
        tweet_id = $1
      end

      tweet = find_tweet(tweet_id)
      @client.oembed tweet if tweet
    end

    def cache_key
      Digest::MD5.hexdigest("#{self.class.name}-#{@params}")
    end

    private

    def find_tweet(id)
      return unless id

      @client.status(id.to_i)
    rescue Twitter::Error::NotFound
      nil
    end
  end

  class UnknownTagFetcher
    def fetch; end
    def cache_key; end
  end

  class TwitterTag < Liquid::Tag
    ERROR_BODY_TEXT = "Tweet could not be processed"

    def initialize(_name, params, _tokens)
      super
      @params  = params.split(/\s+/).map(&:strip)
      @cache   = FileCache.new("../.tweet-cache")

      create_client
    end

    def render(context)
      type = @params.first
      tweet_params  = @params.last

      klass_name = type.capitalize
      if TwitterJekyll.const_defined?(klass_name)
        fetcher_klass = TwitterJekyll.const_get(klass_name)
        fetcher = fetcher_klass.new(@client, tweet_params)
      else
        fetcher = UnknownTagFetcher.new
      end

      html_output_for(fetcher, tweet_params)
    end

    private

    def html_output_for(fetcher, tweet_params)
      body = ERROR_BODY_TEXT

      if response = cached_response(fetcher) || live_response(fetcher)
        body = response.html || body
      end

      "<div class='embed twitter'>#{body}</div>"
    end

    def live_response(fetcher)
      if response = fetcher.fetch
        @cache.write(fetcher.cache_key, response)
        response
      end
    end

    def cached_response(fetcher)
      response = @cache.read(fetcher.cache_key)
      OpenStruct.new(response) unless response.nil?
    end

    def create_client
      @client = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV.fetch('twitter_consumer_key')
        config.consumer_secret     = ENV.fetch('twitter_consumer_secret')
        config.access_token        = ENV.fetch('twitter_access_token')
        config.access_token_secret = ENV.fetch('twitter_access_token_secret')
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
