# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Morgue" do
  let(:job_data) do
    {
      "jid"             => "dead456",
      "class"           => "DeadWorker",
      "args"            => [99],
      "queue"           => "critical",
      "enqueued_at"     => Time.now.to_f,
      "error_class"     => "NoMethodError",
      "error_message"   => "undefined method",
      "error_backtrace" => nil
    }
  end

  let(:fake_job) do
    dbl = double("dead_job", jid: "dead456")
    allow(dbl).to receive(:[]) { |k| job_data[k] }
    allow(dbl).to receive(:retry)
    allow(dbl).to receive(:delete)
    dbl
  end

  let(:fake_dead_set) do
    dbl = double("dead_set", size: 1)
    allow(dbl).to receive(:map) { |&blk| blk ? [fake_job].map(&blk) : [fake_job] }
    allow(dbl).to receive(:find) { |&blk| [fake_job].find(&blk) }
    allow(dbl).to receive(:retry_all)
    allow(dbl).to receive(:clear)
    dbl
  end

  before do
    allow(Sidekiq::DeadSet).to receive(:new).and_return(fake_dead_set)
  end

  describe "GET /morgue" do
    it "returns 200" do
      get "/morgue"
      expect(last_response.status).to eq(200)
    end

    it "renders the job class name" do
      get "/morgue"
      expect(last_response.body).to include("DeadWorker")
    end

    it "renders the error class" do
      get "/morgue"
      expect(last_response.body).to include("NoMethodError")
    end
  end

  describe "GET /morgue/:key" do
    context "with a valid jid" do
      it "returns 200" do
        get "/morgue/dead456"
        expect(last_response.status).to eq(200)
      end

      it "renders job details" do
        get "/morgue/dead456"
        expect(last_response.body).to include("dead456")
        expect(last_response.body).to include("DeadWorker")
        expect(last_response.body).to include("NoMethodError")
      end
    end

    context "with an unknown jid" do
      before { allow(fake_dead_set).to receive(:find).and_return(nil) }

      it "returns 404" do
        get "/morgue/unknown"
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe "POST /morgue" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/morgue", {action: "delete", key: ["dead456"]}
      expect(last_response.status).to eq(403)
    end

    it "deletes the job and redirects" do
      expect(fake_job).to receive(:delete)
      post "/morgue", {action: "delete", key: ["dead456"]}, headers
      expect(last_response.status).to eq(302)
    end

    it "retries the job and redirects" do
      expect(fake_job).to receive(:retry)
      post "/morgue", {action: "retry", key: ["dead456"]}, headers
      expect(last_response.status).to eq(302)
    end

    it "handles unknown jid gracefully" do
      allow(fake_dead_set).to receive(:find).and_return(nil)
      post "/morgue", {action: "delete", key: ["nope"]}, headers
      expect(last_response.status).to eq(302)
    end
  end

  describe "POST /morgue/all/:op" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/morgue/all/delete"
      expect(last_response.status).to eq(403)
    end

    it "retries all and redirects" do
      expect(fake_dead_set).to receive(:retry_all)
      post "/morgue/all/retry", {}, headers
      expect(last_response.status).to eq(302)
    end

    it "deletes all and redirects" do
      expect(fake_dead_set).to receive(:clear)
      post "/morgue/all/delete", {}, headers
      expect(last_response.status).to eq(302)
    end
  end
end
