# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Dashboard" do
  let(:fake_stats) do
    instance_double(
      Sidekiq::Stats,
      processed: 0,
      failed: 0,
      workers_size: 0,
      enqueued: 0,
      retry_size: 0,
      scheduled_size: 0,
      dead_size: 0
    )
  end

  let(:fake_history) do
    instance_double(
      Sidekiq::Stats::History,
      processed: {"2026-05-09" => 0},
      failed: {"2026-05-09" => 0}
    )
  end

  before do
    allow(Sidekiq::Stats).to receive(:new).and_return(fake_stats)
    allow(Sidekiq::Stats::History).to receive(:new).and_return(fake_history)
    allow(Sidekiq).to receive(:redis).and_return({})
  end

  describe "GET /" do
    it "returns 200" do
      get "/"
      expect(last_response.status).to eq(200)
    end

    it "renders the nav" do
      get "/"
      expect(last_response.body).to include("SideBro")
    end

    it "renders stat labels" do
      get "/"
      expect(last_response.body).to include("Processed")
      expect(last_response.body).to include("Failed")
    end
  end

  describe "GET /stats" do
    it "returns JSON with all required keys" do
      get "/stats"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("application/json")
      data = JSON.parse(last_response.body)
      %w[processed failed busy enqueued retries scheduled dead sidekiq].each do |key|
        expect(data).to have_key(key)
      end
    end
  end

  describe "GET /stats/queues" do
    before do
      allow(Sidekiq::Queue).to receive(:all).and_return([])
    end

    it "returns JSON" do
      get "/stats/queues"
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data).to be_a(Hash)
    end
  end
end
