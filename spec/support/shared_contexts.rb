RSpec.shared_context "without cached response" do
  let(:cache) { null_cache }

  before do
    subject.cache = cache
  end

  def null_cache
    double("TwitterJekyll::NullCache", read: nil, write: nil)
  end
end

RSpec.shared_context "with any oembed request and response" do
  let(:options) { "oembed https://twitter.com/twitter_user/status/12345" }
  let(:response) { OpenStruct.new(html: "<p>tweet html</p>") }

  before do
    allow(api_client).to receive(:oembed).and_return(response)
  end
end
