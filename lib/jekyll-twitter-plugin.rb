# frozen_string_literal: true
require "fileutils"
require "twitter"

##
# A Liquid tag plugin for Jekyll that renders Tweets from Twitter API.
# https://github.com/rob-murray/jekyll-twitter-plugin
#
module TwitterJekyll
  MissingApiKeyError = Class.new(StandardError)
  TwitterSecrets = Struct.new(:consumer_key, :consumer_secret, :access_token, :access_token_secret) do
    def self.build(source, keys)
      new(*source.values_at(*keys))
    end
  end
  CONTEXT_API_KEYS    = %w(consumer_key consumer_secret access_token access_token_secret).freeze
  ENV_API_KEYS        = %w(TWITTER_CONSUMER_KEY TWITTER_CONSUMER_SECRET TWITTER_ACCESS_TOKEN TWITTER_ACCESS_TOKEN_SECRET).freeze
  TWITTER_STATUS_URL  = %r{\Ahttps?://twitter\.com/(:#!\/)?\w+/status(es)?/\d+}i
  REFER_TO_README     = "Please see 'https://github.com/rob-murray/jekyll-twitter-plugin' for usage."

  class FileCache
    def initialize(path)
      @cache_folder = File.expand_path path
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
    def initialize(*_args); end

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
    ERRORS_TO_IGNORE = [Twitter::Error::NotFound, Twitter::Error::Forbidden].freeze

    attr_reader :error

    def initialize(client, params)
      @client = client
      @status_url = params.shift
      parse_args(params)
    end

    def fetch; end

    private

    def id_from_status_url(url)
      Regexp.last_match[1] if url.to_s =~ %r{([^\/]+$)}
    end

    def find_tweet(id)
      return unless id

      @client.status(id.to_i)
    rescue *ERRORS_TO_IGNORE => e
      @error = create_error(e)
      return nil
    end

    def parse_args(args)
      @params ||= begin
        args.each_with_object({}) do |arg, params|
          k, v = arg.split("=").map(&:strip)
          if k && v
            v = Regexp.last_match[1] if v =~ /^'(.*)'$/
            params[k] = v
          end
        end
      end
    end

    def create_error(exception)
      ErrorResponse.new("There was a '#{exception.class.name}' error fetching Tweet '#{@status_url}'")
    end
  end

  class Oembed < TwitterApi
    include TwitterJekyll::Cacheable

    def fetch
      tweet_id = id_from_status_url(@status_url)

      if tweet = find_tweet(tweet_id)
        # To work around a 'bug' in the Twitter gem modifying our hash we pass in
        # a copy otherwise our cache key is altered.
        @client.oembed tweet, @params.dup
      else
        error
      end
    end

    private

    def key
      format("%s-%s", @status_url, @params.to_s)
    end
  end

  class ErrorResponse
    attr_reader :error

    def initialize(error)
      @error = error
    end

    def html
      "<p>#{@error}</p>"
    end

    def to_h
      { html: html }
    end
  end

  class TwitterTag < Liquid::Tag
    ERROR_BODY_TEXT   = "<p>Tweet could not be processed</p>"
    DEFAULT_API_TYPE  = "oembed"

    attr_writer :cache # for testing

    def initialize(_name, params, _tokens)
      super
      @api_type, @params = parse_params(params)
    end

    def self.cache_klass
      FileCache
    end

    def render(context)
      secrets = find_secrets!(context)
      create_twitter_rest_client(secrets)
      api_client = create_api_client(@api_type, @params)
      response = cached_response(api_client) || live_response(api_client)
      html_output_for(response)
    end

    private

    def cache
      @cache ||= self.class.cache_klass.new("./.tweet-cache")
    end

    def html_output_for(response)
      body = (response.html if response) || ERROR_BODY_TEXT

      "<div class='embed twitter'>#{body}</div>"
    end

    def live_response(api_client)
      if response = api_client.fetch
        cache.write(api_client.cache_key, response)
        response
      end
    end

    def cached_response(api_client)
      response = cache.read(api_client.cache_key)
      OpenStruct.new(response) unless response.nil?
    end

    def parse_params(params)
      args = params.split(/\s+/).map(&:strip)

      case args[0]
      when DEFAULT_API_TYPE
        api_type, *api_args = args
        [api_type, api_args]
      when TWITTER_STATUS_URL
        [DEFAULT_API_TYPE, args]
      else
        invalid_args!(args)
      end
    end

    def create_api_client(api_type, params)
      klass_name = api_type.capitalize
      api_client_klass = TwitterJekyll.const_get(klass_name)
      api_client_klass.new(@twitter_client, params)
    end

    def create_twitter_rest_client(secrets)
      @twitter_client = Twitter::REST::Client.new do |config|
        config.consumer_key        = secrets.consumer_key
        config.consumer_secret     = secrets.consumer_secret
        config.access_token        = secrets.access_token
        config.access_token_secret = secrets.access_token_secret
      end
    end

    def find_secrets!(context)
      extract_twitter_secrets_from_context(context) || extract_twitter_secrets_from_env || missing_keys!
    end

    def extract_twitter_secrets_from_context(context)
      twitter_secrets = context.registers[:site].config.fetch("twitter", {})
      return unless store_has_keys?(twitter_secrets, CONTEXT_API_KEYS)

      TwitterSecrets.build(twitter_secrets, CONTEXT_API_KEYS)
    end

    def extract_twitter_secrets_from_env
      return unless store_has_keys?(ENV, ENV_API_KEYS)

      TwitterSecrets.build(ENV, ENV_API_KEYS)
    end

    def store_has_keys?(store, keys)
      keys.all? { |required_key| store.key?(required_key) }
    end

    def missing_keys!
      raise MissingApiKeyError, "Twitter API keys not found. You can specify these in Jekyll config or ENV. #{REFER_TO_README}"
    end

    def invalid_args!(arguments)
      formatted_args = Array(arguments).join(" ")
      raise ArgumentError, "Invalid arguments '#{formatted_args}' passed to 'jekyll-twitter-plugin'. #{REFER_TO_README}"
    end
  end

  class TwitterTagNoCache < TwitterTag
    def self.cache_klass
      NullCache
    end
  end
end

Liquid::Template.register_tag("twitter", TwitterJekyll::TwitterTag)
Liquid::Template.register_tag("twitternocache", TwitterJekyll::TwitterTagNoCache)
