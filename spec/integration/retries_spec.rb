# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Retries" do
  let(:fake_retry_set) do
    instance_double(Sidekiq::RetrySet, size: 0, map: [])
  end

  before do
    allow(Sidekiq::RetrySet).to receive(:new).and_return(fake_retry_set)
    allow(fake_retry_set).to receive(:find).and_return(nil)
  end

  describe "GET /retries" do
    it "returns 200" do
      get "/retries"
      expect(last_response.status).to eq(200)
    end

    it "renders retries heading" do
      get "/retries"
      expect(last_response.body).to include("Retries")
    end
  end

  describe "GET /retries/:key with unknown key" do
    it "returns 404" do
      get "/retries/nonexistentjid"
      expect(last_response.status).to eq(404)
    end
  end

  describe "POST /retries without same-origin" do
    it "returns 403" do
      post "/retries", {action: "delete"}
      expect(last_response.status).to eq(403)
    end
  end
end
