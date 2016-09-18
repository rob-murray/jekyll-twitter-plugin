# frozen_string_literal: true
RSpec.describe TwitterJekyll::Oembed do
  let(:api_client) { double("Twitter::REST::Client") }
  let(:status_response) { double }
  subject { described_class.new(api_client, params) }

  describe "parsing status id" do
    let(:params) { ["https://twitter.com/twitter_user/status/12345"] }

    it "parses the status id from the tweet url correctly" do
      status_response = double
      allow(Twitter::REST::Client).to receive(:new).and_return(api_client)

      expect(api_client).to receive(:status).with(12_345).and_return(status_response)
      expect(api_client).to receive(:oembed).with(status_response, {}).and_return("")
      subject.fetch
    end
  end

  describe "parsing options" do
    context "with extra options" do
      let(:params) { ["https://twitter.com/twitter_user/status/12345", "align='right'", "width='350'"] }

      it "passes to api" do
        allow(Twitter::REST::Client).to receive(:new).and_return(api_client)
        allow(api_client).to receive(:status).with(12_345).and_return(status_response)

        expect(api_client).to receive(:oembed).with(status_response, "align" => "right", "width" => "350").and_return("")
        subject.fetch
      end
    end

    context "with an invalid option" do
      let(:params) { ["https://twitter.com/twitter_user/status/12345", "align=", "width='350'"] }

      it "ignores param" do
        allow(Twitter::REST::Client).to receive(:new).and_return(api_client)
        allow(api_client).to receive(:status).with(12_345).and_return(status_response)

        expect(api_client).to receive(:oembed).with(status_response, "width" => "350").and_return("")
        subject.fetch
      end
    end
  end

  describe "#fetch" do
    let(:params) { ["https://twitter.com/twitter_user/status/12345"] }

    it "returns response from api" do
      allow(Twitter::REST::Client).to receive(:new).and_return(api_client)
      allow(api_client).to receive(:status).with(12_345).and_return(status_response)

      expect(api_client).to receive(:oembed).with(status_response, {}).and_return("api response")
      expect(subject.fetch).to eq "api response"
    end

    context "when status is not found" do
      it "returns error" do
        allow(Twitter::REST::Client).to receive(:new).and_return(api_client)
        allow(api_client).to receive(:status).with(12_345).and_raise(Twitter::Error::NotFound)

        expect(api_client).not_to receive(:oembed)
        result = subject.fetch
        expect(result).to be_a(TwitterJekyll::ErrorResponse)
        expect(result.error).to eq "There was a 'Twitter::Error::NotFound' error fetching Tweet 'https://twitter.com/twitter_user/status/12345'"
      end
    end
  end

  describe "#cache_key" do
    context "with no params" do
      let(:params) { ["https://twitter.com/twitter_user/status/12345"] }

      it "matches on status url" do
        oembed_1 = TwitterJekyll::Oembed.new(api_client, params.dup)
        oembed_2 = TwitterJekyll::Oembed.new(api_client, params.dup)

        expect(
          oembed_1.cache_key == oembed_2.cache_key
        ).to be true
      end
    end

    context "with params" do
      let(:params_1) { ["https://twitter.com/twitter_user/status/12345", "align='right'"] }
      let(:params_2) { ["https://twitter.com/twitter_user/status/12345", "align='left'"] }

      it "matches on keys and values" do
        oembed_1 = TwitterJekyll::Oembed.new(api_client, params_1.dup)
        oembed_2 = TwitterJekyll::Oembed.new(api_client, params_2.dup)
        oembed_3 = TwitterJekyll::Oembed.new(api_client, params_1.dup)

        expect(
          oembed_1.cache_key == oembed_2.cache_key
        ).to be false

        expect(
          oembed_1.cache_key == oembed_3.cache_key
        ).to be true
      end
    end
  end
end
