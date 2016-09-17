# frozen_string_literal: true
RSpec.describe TwitterJekyll::Oembed do
  let(:api_client) { double("Twitter::REST::Client") }

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
