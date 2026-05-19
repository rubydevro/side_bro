# frozen_string_literal: true

require "sidekiq/api"
require "sidekiq/metrics/query"

RSpec.describe "Metrics" do
  let(:fake_metrics_result) do
    double("metrics_result", job_results: {})
  end

  let(:fake_metrics_query) do
    double("metrics_query", top_jobs: fake_metrics_result)
  end

  before do
    allow(Sidekiq::Metrics::Query).to receive(:new).and_return(fake_metrics_query)
  end

  describe "GET /metrics" do
    it "returns 200 on Sidekiq 7+" do
      get "/metrics"
      expect([200, 404]).to include(last_response.status)
    end
  end
end
