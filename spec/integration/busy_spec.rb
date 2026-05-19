# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Busy" do
  before do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return(instance_double(Sidekiq::ProcessSet, to_a: [], each: []))
    allow(Sidekiq::WorkSet).to receive(:new).and_return(instance_double(Sidekiq::WorkSet, to_a: []))
  end

  describe "GET /busy" do
    it "returns 200" do
      get "/busy"
      expect(last_response.status).to eq(200)
    end

    it "renders processes heading" do
      get "/busy"
      expect(last_response.body).to include("Processes")
    end
  end

  describe "POST /busy without same-origin header" do
    it "returns 403" do
      post "/busy", {quiet: 1}
      expect(last_response.status).to eq(403)
    end
  end

  describe "POST /busy with same-origin header" do
    it "redirects" do
      post "/busy", {quiet: "1"}, {"HTTP_SEC_FETCH_SITE" => "same-origin"}
      expect(last_response.status).to eq(302)
    end
  end
end
