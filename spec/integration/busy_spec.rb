# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Busy" do
  let(:fake_process) do
    data = {
      "hostname"     => "myhost",
      "pid"          => 1234,
      "queues"       => ["default"],
      "concurrency"  => 5,
      "busy"         => 2,
      "rss"          => 51_200,
      "started_at"   => Time.now.to_f,
      "tag"          => ""
    }
    dbl = double("process", identity: "myhost:1234:abc")
    allow(dbl).to receive(:[]) { |k| data[k] }
    allow(dbl).to receive(:quiet!)
    allow(dbl).to receive(:stop!)
    dbl
  end

  let(:fake_process_set) do
    dbl = double("process_set")
    allow(dbl).to receive(:to_a).and_return([fake_process])
    allow(dbl).to receive(:each) { |&blk| blk ? [fake_process].each(&blk) : [fake_process].each }
    allow(dbl).to receive(:find) { |&blk| [fake_process].find(&blk) }
    dbl
  end

  before do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return(fake_process_set)
    allow(Sidekiq::WorkSet).to receive(:new).and_return(double("work_set", to_a: []))
  end

  describe "GET /busy" do
    it "returns 200" do
      get "/busy"
      expect(last_response.status).to eq(200)
    end

    it "renders the processes heading" do
      get "/busy"
      expect(last_response.body).to include("Processes")
    end

    it "renders the process hostname" do
      get "/busy"
      expect(last_response.body).to include("myhost")
    end
  end

  describe "POST /busy" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/busy", {quiet: "1"}
      expect(last_response.status).to eq(403)
    end

    it "quiets all processes and redirects" do
      expect(fake_process).to receive(:quiet!)
      post "/busy", {quiet: "1"}, headers
      expect(last_response.status).to eq(302)
    end

    it "stops all processes and redirects" do
      expect(fake_process).to receive(:stop!)
      post "/busy", {stop: "1"}, headers
      expect(last_response.status).to eq(302)
    end

    it "quiets a specific process by identity" do
      expect(fake_process).to receive(:quiet!)
      post "/busy", {identity: "myhost:1234:abc", quiet_process: "1"}, headers
      expect(last_response.status).to eq(302)
    end

    it "stops a specific process by identity" do
      expect(fake_process).to receive(:stop!)
      post "/busy", {identity: "myhost:1234:abc", stop_process: "1"}, headers
      expect(last_response.status).to eq(302)
    end

    it "does nothing for unknown identity" do
      expect(fake_process).not_to receive(:quiet!)
      post "/busy", {identity: "unknown:0:x", quiet_process: "1"}, headers
      expect(last_response.status).to eq(302)
    end
  end
end
