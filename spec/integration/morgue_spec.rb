# frozen_string_literal: true

require "sidekiq/api"

RSpec.describe "Morgue" do
  let(:fake_dead_set) do
    instance_double(Sidekiq::DeadSet, size: 0, map: [])
  end

  before do
    allow(Sidekiq::DeadSet).to receive(:new).and_return(fake_dead_set)
    allow(fake_dead_set).to receive(:find).and_return(nil)
  end

  describe "GET /morgue" do
    it "returns 200" do
      get "/morgue"
      expect(last_response.status).to eq(200)
    end
  end

  describe "GET /morgue/:key with unknown key" do
    it "returns 404" do
      get "/morgue/nonexistentjid"
      expect(last_response.status).to eq(404)
    end
  end
end
