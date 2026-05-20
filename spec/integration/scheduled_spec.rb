# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Scheduled" do
  let(:job_data) do
    {
      "jid"         => "sched789",
      "class"       => "ScheduledWorker",
      "args"        => ["task"],
      "queue"       => "default",
      "enqueued_at" => Time.now.to_f
    }
  end

  let(:fake_job) do
    run_at = Time.now + 3600
    dbl = double("scheduled_job", jid: "sched789", score: run_at.to_f, at: run_at)
    allow(dbl).to receive(:[]) { |k| job_data[k] }
    allow(dbl).to receive(:delete)
    allow(dbl).to receive(:add_to_queue)
    dbl
  end

  let(:fake_scheduled_set) do
    dbl = double("scheduled_set", size: 1)
    allow(dbl).to receive(:map) { |&blk| blk ? [fake_job].map(&blk) : [fake_job] }
    allow(dbl).to receive(:find) { |&blk| [fake_job].find(&blk) }
    allow(dbl).to receive(:clear)
    allow(dbl).to receive(:each) { |&blk| blk ? [fake_job].each(&blk) : [fake_job].each }
    dbl
  end

  before do
    allow(Sidekiq::ScheduledSet).to receive(:new).and_return(fake_scheduled_set)
  end

  describe "GET /scheduled" do
    it "returns 200" do
      get "/scheduled"
      expect(last_response.status).to eq(200)
    end

    it "renders the job class name" do
      get "/scheduled"
      expect(last_response.body).to include("ScheduledWorker")
    end
  end

  describe "GET /scheduled/:key" do
    context "with a valid jid" do
      it "returns 200" do
        get "/scheduled/sched789"
        expect(last_response.status).to eq(200)
      end

      it "renders job details" do
        get "/scheduled/sched789"
        expect(last_response.body).to include("sched789")
        expect(last_response.body).to include("ScheduledWorker")
      end
    end

    context "with an unknown jid" do
      before { allow(fake_scheduled_set).to receive(:find).and_return(nil) }

      it "returns 404" do
        get "/scheduled/unknown"
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe "POST /scheduled" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/scheduled", {action: "delete", key: ["sched789"]}
      expect(last_response.status).to eq(403)
    end

    it "deletes the job and redirects" do
      expect(fake_job).to receive(:delete)
      post "/scheduled", {action: "delete", key: ["sched789"]}, headers
      expect(last_response.status).to eq(302)
    end

    it "enqueues the job immediately and redirects" do
      expect(fake_job).to receive(:add_to_queue)
      post "/scheduled", {action: "add_to_queue", key: ["sched789"]}, headers
      expect(last_response.status).to eq(302)
    end

    it "handles unknown jid gracefully" do
      allow(fake_scheduled_set).to receive(:find).and_return(nil)
      post "/scheduled", {action: "delete", key: ["nope"]}, headers
      expect(last_response.status).to eq(302)
    end
  end

  describe "POST /scheduled/all/:op" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/scheduled/all/delete"
      expect(last_response.status).to eq(403)
    end

    it "clears all scheduled jobs and redirects" do
      expect(fake_scheduled_set).to receive(:clear)
      post "/scheduled/all/delete", {}, headers
      expect(last_response.status).to eq(302)
    end

    it "enqueues all scheduled jobs and redirects" do
      expect(fake_scheduled_set).to receive(:each)
      post "/scheduled/all/add_to_queue", {}, headers
      expect(last_response.status).to eq(302)
    end
  end
end
