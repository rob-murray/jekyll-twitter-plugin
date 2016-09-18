# frozen_string_literal: true
RSpec.describe TwitterJekyll::TwitterTag do
  let(:context) { double.as_null_object }
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

  subject { described_class.new(nil, options, nil) }
  let(:options) { "" }

  context "with cached response" do
    let(:options) { "oembed https://twitter.com/a/status" }
    let(:cache) { double("TwitterJekyll::FileCache") }
    before do
      subject.cache = cache
    end

    it "renders response from cache" do
      allow(Twitter::REST::Client).to receive(:new).and_return(double.as_null_object)
      expect(cache).to receive(:read).with(an_instance_of(String)).and_return(api_response_hash)

      output = subject.render(context)
      expect_output_to_match_tag_content(output, api_response_hash.fetch("html"))
    end
  end

  context "without cached response" do
    let(:options) { "oembed https://twitter.com/twitter_user/status/12345" }
    let(:cache) { double("TwitterJekyll::FileCache") }
    let(:response) { build_response_object(api_response_hash) }
    before do
      subject.cache = cache
      allow(cache).to receive(:read).with(an_instance_of(String)).and_return(nil)
    end

    context "with successful api request" do
      it "renders response from api and writes to cache" do
        api_client = double("Twitter::REST::Client", status: double)
        allow(Twitter::REST::Client).to receive(:new).and_return(api_client)

        expect(api_client).to receive(:oembed).and_return(response)
        expect(cache).to receive(:write).with(an_instance_of(String), response)

        output = subject.render(context)
        expect_output_to_match_tag_content(output, api_response_hash.fetch("html"))
      end
    end

    context "with a status not found api request" do
      it "renders response from api and does not write to cache" do
        api_client = double("Twitter::REST::Client", status: double)
        allow(Twitter::REST::Client).to receive(:new).and_return(api_client)

        expect(api_client).to receive(:status).and_raise(Twitter::Error::NotFound)
        expect(cache).not_to receive(:write).with(an_instance_of(String), response)

        output = subject.render(context)
        expect_output_to_have_error(output, Twitter::Error::NotFound)
      end
    end

    context "with a status request not permitted api request" do
      it "renders response from api and does not write to cache" do
        api_client = double("Twitter::REST::Client", status: double)
        allow(Twitter::REST::Client).to receive(:new).and_return(api_client)

        expect(api_client).to receive(:status).and_raise(Twitter::Error::Forbidden)
        expect(cache).not_to receive(:write).with(an_instance_of(String), response)

        output = subject.render(context)
        expect_output_to_have_error(output, Twitter::Error::Forbidden)
      end
    end

    describe "parsing api request type" do
      let(:cache) { double("TwitterJekyll::FileCache").as_null_object }

      context "with oembed requested" do
        let(:options) { "oembed https://twitter.com/twitter_user/status/12345" }
        let(:status) { double }

        it "uses the oembed api" do
          api_client = double("Twitter::REST::Client", status: status)
          allow(Twitter::REST::Client).to receive(:new).and_return(api_client)

          expect(api_client).to receive(:oembed).with(status, {}).and_return(response)
          subject.render(context)
        end
      end

      context "with an api request not supported" do
        let(:options) { "unsupported https://twitter.com/twitter_user/status/12345" }

        it "renders error message" do
          api_client = double("Twitter::REST::Client", status: double)
          allow(Twitter::REST::Client).to receive(:new).and_return(api_client)

          expect(api_client).not_to receive(:oembed)
          output = subject.render(context)
          expect_output_to_match_tag_content(output, "<p>Tweet could not be processed</p>")
        end
      end
    end

    describe "parsing api secrets" do
      let(:cache) { double("TwitterJekyll::FileCache").as_null_object }
      let(:api_client) { double("Twitter::REST::Client", status: double) }
      let(:builder) { double }
      before do
        allow(Twitter::REST::Client).to receive(:new).and_yield(builder).and_return(api_client)
        allow(api_client).to receive(:oembed).and_return(response)
      end

      context "with api secrets provided by ENV" do
        let(:context) { double("context", registers: { site: double(config: {}) }) }
        before do
          stub_const("ENV", "TWITTER_CONSUMER_KEY" => "consumer_key",
                            "TWITTER_CONSUMER_SECRET" => "consumer_secret",
                            "TWITTER_ACCESS_TOKEN" => "access_token",
                            "TWITTER_ACCESS_TOKEN_SECRET" => "access_token_secret")
        end

        it "creates api client correctly" do
          expect(builder).to receive(:consumer_key=).with("consumer_key")
          expect(builder).to receive(:consumer_secret=).with("consumer_secret")
          expect(builder).to receive(:access_token=).with("access_token")
          expect(builder).to receive(:access_token_secret=).with("access_token_secret")

          subject.render(context)
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

        it "creates api client correctly" do
          expect(builder).to receive(:consumer_key=).with("consumer_key")
          expect(builder).to receive(:consumer_secret=).with("consumer_secret")
          expect(builder).to receive(:access_token=).with("access_token")
          expect(builder).to receive(:access_token_secret=).with("access_token_secret")

          subject.render(context)
        end
      end

      context "with no api secrets provided" do
        let(:context) { double("context", registers: { site: double(config: {}) }) }
        before do
          stub_const("ENV", {})
        end

        it "raises an exception" do
          expect do
            subject.render(context)
          end.to raise_error(TwitterJekyll::MissingApiKeyError)
        end
      end
    end
  end

  private

  def expect_output_to_match_tag_content(actual, content)
    expect(actual).to eq(
      "<div class='embed twitter'>#{content}</div>"
    )
  end

  def expect_output_to_have_error(actual, error)
    expect_output_to_match_tag_content(actual, "<p>There was a '#{error}' error fetching Tweet 'https://twitter.com/twitter_user/status/12345'</p>")
  end

  # The twitter gem responds with a stuct like object so we do too.
  def build_response_object(response)
    OpenStruct.new(response)
  end
end
