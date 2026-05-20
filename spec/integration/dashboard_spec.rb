# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Dashboard" do
  let(:fake_stats) do
    instance_double(
      Sidekiq::Stats,
      processed: 1234,
      failed: 56,
      workers_size: 3,
      enqueued: 78,
      retry_size: 9,
      scheduled_size: 2,
      dead_size: 1
    )
  end

  let(:fake_history) do
    instance_double(
      Sidekiq::Stats::History,
      processed: {"2026-05-09" => 100},
      failed: {"2026-05-09" => 5}
    )
  end

  before do
    allow(Sidekiq::Stats).to receive(:new).and_return(fake_stats)
    allow(Sidekiq::Stats::History).to receive(:new).and_return(fake_history)
    allow(Sidekiq).to receive(:redis).and_return({})
  end

  describe "HEAD /" do
    it "returns 200 when Redis is reachable" do
      allow(Sidekiq).to receive(:redis).and_yield(double(ping: "PONG"))
      head "/"
      expect(last_response.status).to eq(200)
    end

    it "returns 500 when Redis raises" do
      allow(Sidekiq).to receive(:redis).and_raise(RuntimeError, "connection refused")
      head "/"
      expect(last_response.status).to eq(500)
    end
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

    it "renders stat values" do
      get "/"
      expect(last_response.body).to include("1,234")
      expect(last_response.body).to include("56")
    end

    it "renders all summary stat labels" do
      get "/"
      %w[Processed Failed Busy Enqueued Retries Scheduled Dead].each do |label|
        expect(last_response.body).to include(label)
      end
    end
  end

  describe "GET /stats" do
    it "returns 200 with JSON content type" do
      get "/stats"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("application/json")
    end

    it "returns all required keys" do
      get "/stats"
      data = JSON.parse(last_response.body)
      %w[processed failed busy enqueued retries scheduled dead sidekiq].each do |key|
        expect(data).to have_key(key)
      end
    end

    it "returns correct stat values" do
      get "/stats"
      data = JSON.parse(last_response.body)
      expect(data["processed"]).to eq(1234)
      expect(data["failed"]).to eq(56)
    end
  end

  describe "GET /stats/queues" do
    before do
      fake_q = double("queue", name: "default", size: 10)
      allow(Sidekiq::Queue).to receive(:all).and_return([fake_q])
    end

    it "returns 200 with JSON" do
      get "/stats/queues"
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data).to be_a(Hash)
    end

    it "includes queue sizes by name" do
      get "/stats/queues"
      data = JSON.parse(last_response.body)
      expect(data["default"]).to eq(10)
    end
  end
end
