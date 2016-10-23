# frozen_string_literal: true
RSpec.shared_context "without cached response" do
  let(:cache) { null_cache }

  before do
    subject.cache = cache
  end

  def null_cache
    double("TwitterJekyll::NullCache", read: nil, write: nil)
  end
end

RSpec.shared_context "with a normal request and response" do
  let(:arguments) { "https://twitter.com/twitter_user/status/12345" }
  let(:response) { { html: "<p>tweet html</p>" } }

  before do
    allow(api_client).to receive(:fetch).and_return(response)
    allow(TwitterJekyll::ApiClient).to receive(:new).and_return(api_client)
  end
end
