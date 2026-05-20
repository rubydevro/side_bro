# frozen_string_literal: true

RSpec.describe SideBro::Web::Router do
  subject(:router) { described_class.new }

  describe "#match" do
    it "matches a static GET route" do
      router.get("/") { "root" }
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/"}
      expect(router.match(env)).not_to be_nil
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

    it "matches a dedicated HEAD route before falling back to GET" do
      head_block = -> { "head" }
      get_block  = -> { "get" }
      router.head("/") { head_block.call }
      router.get("/")  { get_block.call }
      env = {"REQUEST_METHOD" => "HEAD", "PATH_INFO" => "/"}
      block = router.match(env)
      expect(block.call).to eq("head")
    end

    it "matches POST routes" do
      router.post("/retries") { "post" }
      env = {"REQUEST_METHOD" => "POST", "PATH_INFO" => "/retries"}
      expect(router.match(env)).not_to be_nil
    end

    it "does not match a POST route for a GET request" do
      router.post("/retries") { "post" }
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/retries"}
      expect(router.match(env)).to be_nil
    end

    it "captures wildcard/splat segments" do
      router.get("/assets/*") { "asset" }
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/assets/stylesheets/style.css"}
      router.match(env)
      expect(env[SideBro::Web::Router::ROUTE_PARAMS]["splat"]).to eq("/stylesheets/style.css")
    end

    it "captures multiple dynamic segments" do
      router.post("/queues/:name/delete") { "delete" }
      env = {"REQUEST_METHOD" => "POST", "PATH_INFO" => "/queues/default/delete"}
      router.match(env)
      expect(env[SideBro::Web::Router::ROUTE_PARAMS]).to eq({"name" => "default"})
    end

    it "matches routes in registration order" do
      first = -> { "first" }
      router.get("/test") { first.call }
      router.get("/test") { "second" }
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/test"}
      block = router.match(env)
      expect(block.call).to eq("first")
    end
  end
end
