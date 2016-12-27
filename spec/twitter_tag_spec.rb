# frozen_string_literal: true
RSpec.describe TwitterJekyll::TwitterTag do
  let(:context) { empty_jekyll_context }
  let(:arguments) { "" }
  let(:api_response_hash) do
    {
      "url" => "https://twitter.com/twitter_user/status/12345",
      "author_name" => "twitter user",
      "author_url" => "https://twitter.com/twitter_user",
      "html" => "<p>tweet html</p>",
      "width" => 550,
      "height" => nil,
      "type" => "rich",
      "cache_age" => "3153600000",
      "provider_name" => "Twitter",
      "provider_url" => "https://twitter.com",
      "version" => "1.0"
    }
  end
  subject { described_class.new(nil, arguments, nil) }

  describe "output from oembed request" do
    let(:arguments) { "https://twitter.com/twitter_user/status/12345" }

    context "with cached response" do
      let(:cache) { double("TwitterJekyll::FileCache") }
      before do
        subject.cache = cache
      end

      it "renders response from cache" do
        expect(cache).to receive(:read).with(an_instance_of(String)).and_return(api_response_hash)

        output = subject.render(context)
        expect_output_to_match_tag_content(output, api_response_hash.fetch("html"))
      end
    end

    context "without cached response" do
      let(:cache) { double("TwitterJekyll::FileCache") }
      before do
        subject.cache = cache
        allow(cache).to receive(:read).with(an_instance_of(String)).and_return(nil)
      end

      context "with successful api request" do
        before do
          stub_api_request(status: 200, body: api_response_hash.to_json, headers: {})
        end

        it "renders response from api and writes to cache" do
          expect(cache).to receive(:write).with(an_instance_of(String), api_response_hash)

          output = subject.render(context)
          expect_output_to_match_tag_content(output, api_response_hash.fetch("html"))
        end
      end

      context "with a status not found api request" do
        before do
          stub_api_request(status: [404, "Not Found"], body: "", headers: {})
        end

        it "renders error response and writes to cache" do
          expect(cache).to receive(:write).with(an_instance_of(String), an_instance_of(Hash))

          output = subject.render(context)
          expect_output_to_have_error(output, "Not Found")
        end
      end

      context "with a status request not permitted api request" do
        before do
          stub_api_request(status: [403, "Forbidden"], body: "", headers: {})
        end

        it "renders error response and writes to cache" do
          expect(cache).to receive(:write).with(an_instance_of(String), an_instance_of(Hash))

          output = subject.render(context)
          expect_output_to_have_error(output, "Forbidden")
        end
      end

      context "with a server error api request" do
        before do
          stub_api_request(status: [500, "Internal Server Error"], body: "", headers: {})
        end

        it "renders error response and writes to cache" do
          expect(cache).to receive(:write).with(an_instance_of(String), an_instance_of(Hash))

          output = subject.render(context)
          expect_output_to_have_error(output, "Internal Server Error")
        end
      end

      context "with api request that times out" do
        before do
          stub_api.to_timeout
        end

        it "renders error response and writes to cache" do
          expect(cache).to receive(:write).with(an_instance_of(String), an_instance_of(Hash))

          output = subject.render(context)
          expect_output_to_have_error(output, "Net::OpenTimeout")
        end
      end

      context "with the oembed api type as the first argument" do
        let(:arguments) { "oembed https://twitter.com/twitter_user/status/12345" }
        before do
          stub_api_request(status: 200, body: api_response_hash.to_json, headers: {})
        end

        it "renders response from api and writes to cache" do
          expect(cache).to receive(:write).with(an_instance_of(String), api_response_hash)

          output = subject.render(context)
          expect_output_to_match_tag_content(output, api_response_hash.fetch("html"))
        end
      end
    end
  end

  describe "parsing arguments" do
    context "without any arguments" do
      let(:arguments) { "" }

      it "raises an exception" do
        expect_to_raise_invalid_args_error(arguments) do
          tag = described_class.new(nil, arguments, nil)
          tag.render(context)
        end
      end
    end

    context "with the oembed api type as the first argument" do
      let(:arguments) { "oembed https://twitter.com/twitter_user/status/12345" }

      it "uses correct twitter url and warns of deprecation" do
        api_client = api_client_double
        allow(api_client).to receive(:fetch).and_return({})
        allow(TwitterJekyll::ApiClient).to receive(:new).and_return(api_client)
        expect(TwitterJekyll::ApiRequest).to receive(:new).with("https://twitter.com/twitter_user/status/12345", {}).and_call_original

        expect do
          tag = described_class.new(nil, arguments, nil)
          tag.render(context)
        end.to output(/Passing 'oembed' as the first argument is not required anymore/).to_stderr
      end
    end
  end

  describe "parsing api secrets" do
    include_context "without cached response"
    include_context "with a normal request and response"
    let(:api_client) { api_client_double }

    context "with api secrets provided by ENV" do
      let(:context) { double("context", registers: { site: double(config: {}) }) }
      before do
        stub_const("ENV", "TWITTER_CONSUMER_KEY" => "consumer_key",
                          "TWITTER_CONSUMER_SECRET" => "consumer_secret",
                          "TWITTER_ACCESS_TOKEN" => "access_token",
                          "TWITTER_ACCESS_TOKEN_SECRET" => "access_token_secret")
      end

      it "warns of deprecation" do
        expect do
          tag = described_class.new(nil, arguments, nil)
          tag.render(context)
        end.to output(/Found Twitter API keys in ENV, this library does not require these keys anymore/).to_stderr
      end
    end

    context "with api secrets provided by Jekyll config" do
      let(:context) do
        api_secrets = %w(consumer_key consumer_secret access_token access_token_secret)
                      .each_with_object({}) { |secret, h| h[secret] = secret }
        double("context", registers:
          { site: double(config: { "twitter" => api_secrets }) })
      end
      before do
        stub_const("ENV", {})
      end

      it "warns of deprecation" do
        expect do
          tag = described_class.new(nil, arguments, nil)
          tag.render(context)
        end.to output(/Found Twitter API keys in Jekyll _config.yml, this library does not require these keys anymore/).to_stderr
      end
    end

    context "with no api secrets provided" do
      let(:context) { empty_jekyll_context }
      before do
        stub_const("ENV", {})
      end

      it "does not warn" do
        expect do
          subject.render(context)
        end.to_not output.to_stderr
      end
    end
  end

  private

  def stub_api_request(response)
    stub_api
      .to_return(response)
  end

  def stub_api
    stub_request(:get, /publish.twitter.com/)
  end

  def empty_jekyll_context
    double("context", registers: { site: double(config: {}) })
  end

  def api_client_double
    double("TwitterJekyll::ApiClient")
  end

  def expect_output_to_match_tag_content(actual, content)
    expect(actual).to eq(
      "<div class='jekyll-twitter-plugin'>#{content}</div>"
    )
  end

  def expect_output_to_have_error(actual, error, tweet_url = "https://twitter.com/twitter_user/status/12345")
    expect_output_to_match_tag_content(actual, "<p>There was a '#{error}' error fetching URL: '#{tweet_url}'</p>")
  end

  def expect_to_raise_invalid_args_error(options)
    raise unless block_given?

    message = "Invalid arguments '#{options}' passed to 'jekyll-twitter-plugin'. Please see 'https://github.com/rob-murray/jekyll-twitter-plugin' for usage."
    expect do
      yield
    end.to raise_error(ArgumentError, message)
  end
end
