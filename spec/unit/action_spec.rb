# frozen_string_literal: true

RSpec.describe SideBro::Web::Action do
  def make_env(method: "GET", path: "/", session: {}, query: "")
    {
      "REQUEST_METHOD" => method,
      "PATH_INFO" => path,
      "SCRIPT_NAME" => "",
      "QUERY_STRING" => query,
      "rack.input" => StringIO.new,
      "rack.session" => session,
      SideBro::Web::Router::ROUTE_PARAMS => {}
    }
  end

  describe "#params" do
    it "merges query string params with route params" do
      env = make_env(query: "page=2")
      env[SideBro::Web::Router::ROUTE_PARAMS] = {"name" => "default"}
      action = described_class.new(env)
      expect(action.params["page"]).to eq("2")
      expect(action.params["name"]).to eq("default")
    end
  end

  describe "#session" do
    it "returns the rack session" do
      env = make_env(session: {"locale" => "en"})
      action = described_class.new(env)
      expect(action.session["locale"]).to eq("en")
    end
  end

  describe "#redirect" do
    it "throws :halt with a 302 response" do
      action = described_class.new(make_env)
      result = catch(:halt) { action.redirect("/somewhere") }
      expect(result[0]).to eq(302)
      expect(result[1]["Location"]).to eq("/somewhere")
    end
  end

  describe "#halt" do
    it "throws :halt with a bare status code" do
      action = described_class.new(make_env)
      result = catch(:halt) { action.halt(404) }
      expect(result[0]).to eq(404)
    end

    it "throws :halt with a full rack response array" do
      action = described_class.new(make_env)
      result = catch(:halt) { action.halt([403, {"Content-Type" => "text/plain"}, ["Forbidden"]]) }
      expect(result[0]).to eq(403)
    end
  end

  describe "#json" do
    it "throws :halt with JSON body and correct content-type" do
      action = described_class.new(make_env)
      result = catch(:halt) { action.json({ok: true}) }
      expect(result[0]).to eq(200)
      expect(result[1]["Content-Type"]).to include("application/json")
      expect(JSON.parse(result[2].first)).to eq("ok" => true)
    end
  end

  describe "#erb" do
    let(:fake_stats) do
      instance_double(Sidekiq::Stats,
        processed: 0, failed: 0, workers_size: 0,
        enqueued: 0, retry_size: 0, scheduled_size: 0, dead_size: 0)
    end

    let(:fake_history) do
      instance_double(Sidekiq::Stats::History,
        processed: {"2026-05-20" => 0}, failed: {"2026-05-20" => 0})
    end

    before do
      allow(Sidekiq::Stats).to receive(:new).and_return(fake_stats)
      allow(Sidekiq::Queue).to receive(:all).and_return([])
      allow(Sidekiq).to receive(:redis).and_return({})
    end

    def render_dashboard
      action = described_class.new(make_env(session: {}))
      # Simulate what the route handler sets before calling erb
      action.instance_variable_set(:@history, fake_history)
      result = catch(:halt) { action.erb(:dashboard) }
      [action, result]
    end

    it "sets a Content-Security-Policy header" do
      _, result = render_dashboard
      csp = result[1]["Content-Security-Policy"]
      expect(csp).to include("default-src 'self'")
      expect(csp).to include("script-src 'nonce-")
    end

    it "embeds the nonce in the CSP header and response body" do
      action, result = render_dashboard
      nonce = action.nonce
      expect(result[1]["Content-Security-Policy"]).to include(nonce)
      expect(result[2].first).to include("nonce=\"#{nonce}\"")
    end
  end

  describe "template caching" do
    it "caches compiled templates across instances" do
      SideBro::Web::Action::TEMPLATE_CACHE.clear
      expect(File).to receive(:read).at_least(:once).and_call_original

      action1 = described_class.new(make_env)
      action1.send(:load_template, :layout)

      expect(File).not_to receive(:read)
      action2 = described_class.new(make_env)
      action2.send(:load_template, :layout)
    end
  end

  describe "#flash" do
    it "stores and reads flash messages" do
      env = make_env(session: {})
      action = described_class.new(env)
      action.flash["notice"] = "Saved!"
      expect(action.flash["notice"]).to eq("Saved!")
    end

    it "clears flash after reading" do
      env = make_env(session: {})
      action = described_class.new(env)
      action.flash["notice"] = "Hello"
      action.flash["notice"]
      expect(env["rack.session"][:flash]).not_to have_key("notice")
    end

    it "returns true for any? when flash has content" do
      env = make_env(session: {})
      action = described_class.new(env)
      action.flash["error"] = "Something went wrong"
      expect(action.flash.any?).to be true
    end

    it "returns false for any? when flash is empty" do
      env = make_env(session: {})
      action = described_class.new(env)
      expect(action.flash.any?).to be false
    end
  end

  describe "#root_path" do
    it "returns / when mounted at root" do
      action = described_class.new(make_env)
      expect(action.root_path).to eq("/")
    end

    it "appends trailing slash to SCRIPT_NAME" do
      env = make_env
      env["SCRIPT_NAME"] = "/admin/sidebro"
      action = described_class.new(env)
      expect(action.root_path).to eq("/admin/sidebro/")
    end

    it "does not double-slash when SCRIPT_NAME already ends with /" do
      env = make_env
      env["SCRIPT_NAME"] = "/admin/"
      action = described_class.new(env)
      expect(action.root_path).to eq("/admin/")
    end
  end
end
