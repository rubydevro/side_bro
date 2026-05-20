# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Retries" do
  let(:job_data) do
    {
      "jid"             => "abc123",
      "class"           => "MyWorker",
      "args"            => [1, "hello"],
      "queue"           => "default",
      "enqueued_at"     => Time.now.to_f,
      "error_class"     => "RuntimeError",
      "error_message"   => "something went wrong",
      "error_backtrace" => nil
    }
  end

  let(:fake_job) do
    dbl = double("retry_job", jid: "abc123")
    allow(dbl).to receive(:[]) { |k| job_data[k] }
    allow(dbl).to receive(:retry)
    allow(dbl).to receive(:delete)
    allow(dbl).to receive(:kill)
    dbl
  end

  let(:fake_retry_set) do
    dbl = double("retry_set", size: 1)
    allow(dbl).to receive(:map) { |&blk| blk ? [fake_job].map(&blk) : [fake_job] }
    allow(dbl).to receive(:find) { |&blk| [fake_job].find(&blk) }
    allow(dbl).to receive(:retry_all)
    allow(dbl).to receive(:clear)
    allow(dbl).to receive(:kill_all)
    dbl
  end

  before do
    allow(Sidekiq::RetrySet).to receive(:new).and_return(fake_retry_set)
  end

  describe "GET /retries" do
    it "returns 200" do
      get "/retries"
      expect(last_response.status).to eq(200)
    end

    it "renders the job class name" do
      get "/retries"
      expect(last_response.body).to include("MyWorker")
    end

    it "renders the error class" do
      get "/retries"
      expect(last_response.body).to include("RuntimeError")
    end

    it "renders job count" do
      get "/retries"
      expect(last_response.body).to include("1")
    end
  end

  describe "GET /retries/:key" do
    context "with a valid jid" do
      it "returns 200" do
        get "/retries/abc123"
        expect(last_response.status).to eq(200)
      end

      it "renders job details" do
        get "/retries/abc123"
        expect(last_response.body).to include("abc123")
        expect(last_response.body).to include("MyWorker")
        expect(last_response.body).to include("RuntimeError")
      end
    end

    context "with an unknown jid" do
      before { allow(fake_retry_set).to receive(:find).and_return(nil) }

      it "returns 404" do
        get "/retries/unknown"
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe "POST /retries" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/retries", {action: "delete", key: ["abc123"]}
      expect(last_response.status).to eq(403)
    end

    it "deletes the job and redirects" do
      expect(fake_job).to receive(:delete)
      post "/retries", {action: "delete", key: ["abc123"]}, headers
      expect(last_response.status).to eq(302)
    end

    it "retries the job and redirects" do
      expect(fake_job).to receive(:retry)
      post "/retries", {action: "retry", key: ["abc123"]}, headers
      expect(last_response.status).to eq(302)
    end

    it "kills the job and redirects" do
      expect(fake_job).to receive(:kill)
      post "/retries", {action: "kill", key: ["abc123"]}, headers
      expect(last_response.status).to eq(302)
    end

    it "handles unknown jid gracefully" do
      allow(fake_retry_set).to receive(:find).and_return(nil)
      post "/retries", {action: "delete", key: ["nope"]}, headers
      expect(last_response.status).to eq(302)
    end
  end

  describe "POST /retries/all/:op" do
    let(:headers) { {"HTTP_SEC_FETCH_SITE" => "same-origin"} }

    it "returns 403 without same-origin header" do
      post "/retries/all/retry"
      expect(last_response.status).to eq(403)
    end

    it "retries all and redirects" do
      expect(fake_retry_set).to receive(:retry_all)
      post "/retries/all/retry", {}, headers
      expect(last_response.status).to eq(302)
    end

    it "deletes all and redirects" do
      expect(fake_retry_set).to receive(:clear)
      post "/retries/all/delete", {}, headers
      expect(last_response.status).to eq(302)
    end

    it "kills all and redirects" do
      expect(fake_retry_set).to receive(:kill_all)
      post "/retries/all/kill", {}, headers
      expect(last_response.status).to eq(302)
    end
  end
end
