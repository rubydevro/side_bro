# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Queues" do
  let(:fake_queue) do
    instance_double(
      Sidekiq::Queue,
      name: "default",
      size: 0,
      map: [],
      each: []
    )
  end

  before do
    allow(Sidekiq::Queue).to receive(:all).and_return([])
    allow(Sidekiq::Queue).to receive(:new).and_return(fake_queue)
  end

  describe "GET /queues" do
    it "returns 200" do
      get "/queues"
      expect(last_response.status).to eq(200)
    end

    it "renders the queues heading" do
      get "/queues"
      expect(last_response.body).to include("Queues")
    end
  end

  describe "GET /queues/:name" do
    before do
      allow(fake_queue).to receive(:size).and_return(0)
      allow(fake_queue).to receive(:map).and_return([])
      allow(fake_queue).to receive(:latency).and_return(0.0)
    end

    it "returns 200 for a valid queue name" do
      get "/queues/default"
      expect(last_response.status).to eq(200)
    end

    it "returns 404 for invalid queue name characters" do
      get "/queues/../evil"
      expect(last_response.status).to eq(404)
    end
  end
end
