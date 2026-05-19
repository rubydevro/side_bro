# frozen_string_literal: true

RSpec.describe SideBro::Web::Router do
  subject(:router) { described_class.new }

  describe "#match" do
    it "matches a static GET route" do
      router.get("/") { "root" }
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/"}
      block = router.match(env)
      expect(block).not_to be_nil
    end

    it "returns nil for unregistered routes" do
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/nope"}
      expect(router.match(env)).to be_nil
    end

    it "captures dynamic segments" do
      router.get("/queues/:name") { "queue" }
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/queues/default"}
      router.match(env)
      expect(env[SideBro::Web::Router::ROUTE_PARAMS]).to eq({"name" => "default"})
    end

    it "does not match partial paths" do
      router.get("/busy") { "busy" }
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/busybody"}
      expect(router.match(env)).to be_nil
    end

    it "falls back to GET routes for HEAD requests" do
      router.get("/") { "root" }
      env = {"REQUEST_METHOD" => "HEAD", "PATH_INFO" => "/"}
      expect(router.match(env)).not_to be_nil
    end

    it "matches POST routes" do
      router.post("/retries") { "post" }
      env = {"REQUEST_METHOD" => "POST", "PATH_INFO" => "/retries"}
      expect(router.match(env)).not_to be_nil
    end
  end
end
