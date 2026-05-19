# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Scheduled" do
  let(:fake_scheduled_set) do
    instance_double(Sidekiq::ScheduledSet, size: 0, map: [])
  end

  before do
    allow(Sidekiq::ScheduledSet).to receive(:new).and_return(fake_scheduled_set)
    allow(fake_scheduled_set).to receive(:find).and_return(nil)
  end

  describe "GET /scheduled" do
    it "returns 200" do
      get "/scheduled"
      expect(last_response.status).to eq(200)
    end
  end

  describe "GET /scheduled/:key with unknown key" do
    it "returns 404" do
      get "/scheduled/nonexistentjid"
      expect(last_response.status).to eq(404)
    end
  end
end
