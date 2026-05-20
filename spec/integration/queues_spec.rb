# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Queues" do
  let(:job_data) do
    {"jid" => "qjid123", "class" => "MyWorker", "args" => [42], "queue" => "default"}
  end

  let(:fake_queue_job) do
    dbl = double("queue_job", jid: "qjid123")
    allow(dbl).to receive(:[]) { |k| job_data[k] }
    allow(dbl).to receive(:delete)
    dbl
  end

  let(:fake_queue) do
    dbl = double("queue", name: "default", size: 1, latency: 0.5, paused?: false)
    allow(dbl).to receive(:respond_to?) { |m| [:pause!, :unpause!, :paused?].include?(m) }
    allow(dbl).to receive(:lazy) { [fake_queue_job].lazy }
    allow(dbl).to receive(:map) { |&blk| blk ? [fake_queue_job].map(&blk) : [fake_queue_job] }
    allow(dbl).to receive(:select) { |&blk| blk ? [fake_queue_job].select(&blk) : [fake_queue_job] }
    allow(dbl).to receive(:find) { |&blk| [fake_queue_job].find(&blk) }
    allow(dbl).to receive(:pause!)
    allow(dbl).to receive(:unpause!)
    allow(dbl).to receive(:clear)
    dbl
  end

  before do
    allow(Sidekiq::Queue).to receive(:all).and_return([fake_queue])
    allow(Sidekiq::Queue).to receive(:new).and_return(fake_queue)
  end

  describe "GET /queues" do
    it "returns 200" do
      get "/queues"
      expect(last_response.status).to eq(200)
    end

    it "renders the queue name" do
      get "/queues"
      expect(last_response.body).to include("default")
    end
  end

  describe "GET /queues/:name" do
    it "returns 200 for a valid queue name" do
      get "/queues/default"
      expect(last_response.status).to eq(200)
    end

    it "renders the job class name" do
      get "/queues/default"
      expect(last_response.body).to include("MyWorker")
    end

    it "returns 404 for invalid queue name characters" do
      get "/queues/../evil"
      expect(last_response.status).to eq(404)
    end

    context "with filter_job param matching the job" do
      it "returns 200 and includes the job" do
        get "/queues/default?filter_job=MyWorker"
        expect(last_response.status).to eq(200)
        expect(last_response.body).to include("MyWorker")
      end
    end

    context "with filter_job param not matching" do
      it "returns 200 with no matching rows" do
        get "/queues/default?filter_job=OtherWorker"
        expect(last_response.status).to eq(200)
        expect(last_response.body).not_to include("qjid123")
      end
    end

    context "with desc direction" do
      it "returns 200" do
        get "/queues/default?direction=desc"
        expect(last_response.status).to eq(200)
      end
    end

    context "with page param" do
      it "returns 200" do
        get "/queues/default?page=2"
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe "POST /queues/:name" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/queues/default", {clear: "1"}
      expect(last_response.status).to eq(403)
    end

    it "clears the queue and redirects" do
      expect(fake_queue).to receive(:clear)
      post "/queues/default", {clear: "1"}, headers
      expect(last_response.status).to eq(302)
    end

    it "pauses the queue and redirects" do
      expect(fake_queue).to receive(:pause!)
      post "/queues/default", {pause: "1"}, headers
      expect(last_response.status).to eq(302)
    end

    it "unpauses the queue and redirects" do
      expect(fake_queue).to receive(:unpause!)
      post "/queues/default", {unpause: "1"}, headers
      expect(last_response.status).to eq(302)
    end

    it "returns 404 for invalid queue name" do
      post "/queues/../evil", {clear: "1"}, headers
      expect(last_response.status).to eq(404)
    end
  end

  describe "POST /queues/:name/delete" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/queues/default/delete", {key_val: ["qjid123"]}
      expect(last_response.status).to eq(403)
    end

    it "deletes the matching job and redirects" do
      expect(fake_queue_job).to receive(:delete)
      post "/queues/default/delete", {key_val: ["qjid123"]}, headers
      expect(last_response.status).to eq(302)
    end

    it "handles unknown jid gracefully" do
      allow(fake_queue).to receive(:find).and_return(nil)
      post "/queues/default/delete", {key_val: ["unknown"]}, headers
      expect(last_response.status).to eq(302)
    end
  end

  describe "POST /queues/:name/delete_filtered" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/queues/default/delete_filtered", {filter_job: "MyWorker"}
      expect(last_response.status).to eq(403)
    end

    it "deletes jobs matching the filter and redirects" do
      expect(fake_queue_job).to receive(:delete)
      post "/queues/default/delete_filtered", {filter_job: "MyWorker"}, headers
      expect(last_response.status).to eq(302)
    end

    it "does not delete non-matching jobs" do
      expect(fake_queue_job).not_to receive(:delete)
      post "/queues/default/delete_filtered", {filter_job: "OtherWorker"}, headers
      expect(last_response.status).to eq(302)
    end
  end
end
