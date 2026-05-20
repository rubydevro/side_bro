# frozen_string_literal: true

require "cgi"

RSpec.describe SideBro::WebHelpers do
  let(:helper) do
    Class.new do
      include SideBro::WebHelpers

      attr_writer :test_params

      def request
        @request ||= Rack::Request.new(
          "rack.input"     => StringIO.new,
          "rack.session"   => {},
          "REQUEST_METHOD" => "GET",
          "PATH_INFO"      => "/",
          "SCRIPT_NAME"    => "",
          "QUERY_STRING"   => ""
        )
      end

      def params
        @test_params || {}
      end

      def session
        request.env["rack.session"]
      end

      def halt(code)
        throw :halt, code
      end
    end.new
  end

  describe "#h" do
    it "escapes HTML special characters" do
      expect(helper.h("<script>alert('xss')</script>")).to eq(
        "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
      )
    end

    it "escapes ampersands" do
      expect(helper.h("foo & bar")).to eq("foo &amp; bar")
    end

    it "escapes double quotes" do
      expect(helper.h('say "hi"')).to eq("say &quot;hi&quot;")
    end

    it "converts non-strings via to_s" do
      expect(helper.h(42)).to eq("42")
    end
  end

  describe "#truncate" do
    it "returns the string unchanged when under the limit" do
      expect(helper.truncate("hello", 10)).to eq("hello")
    end

    it "returns the string unchanged when exactly at the limit" do
      str = "a" * 200
      expect(helper.truncate(str, 200)).to eq(str)
    end

    it "truncates long strings with ellipsis" do
      result = helper.truncate("a" * 210, 200)
      expect(result.length).to be <= 202
      expect(result).to end_with("…")
    end

    it "handles nil" do
      expect(helper.truncate(nil)).to be_nil
    end
  end

  describe "#relative_time" do
    it "formats seconds" do
      expect(helper.relative_time(Time.now - 30)).to eq("30s")
    end

    it "formats minutes" do
      expect(helper.relative_time(Time.now - 130)).to eq("2m")
    end

    it "formats hours" do
      expect(helper.relative_time(Time.now - 7200)).to eq("2h")
    end

    it "formats days" do
      expect(helper.relative_time(Time.now - 172_800)).to eq("2d")
    end

    it "returns empty string for nil" do
      expect(helper.relative_time(nil)).to eq("")
    end
  end

  describe "#format_memory" do
    it "returns dash for nil" do
      expect(helper.format_memory(nil)).to eq("–")
    end

    it "formats kilobytes as megabytes" do
      expect(helper.format_memory(51_200)).to eq("50 MB")
    end

    it "formats large values as gigabytes" do
      expect(helper.format_memory(1_048_576)).to eq("1.0 GB")
    end
  end

  describe "#number_with_delimiter" do
    it "returns numbers under 1000 unchanged" do
      expect(helper.number_with_delimiter(999)).to eq("999")
    end

    it "adds a comma at thousands" do
      expect(helper.number_with_delimiter(1_000)).to eq("1,000")
    end

    it "adds multiple commas" do
      expect(helper.number_with_delimiter(1_234_567)).to eq("1,234,567")
    end
  end

  describe "#t" do
    it "returns the English translation" do
      expect(helper.t(:dashboard)).to eq("Dashboard")
    end

    it "falls back to the key name for unknown keys" do
      expect(helper.t(:nonexistent_key_xyz)).to eq("nonexistent_key_xyz")
    end

    it "supports string interpolation" do
      result = helper.t(:page_of, page: 2, total: 10)
      expect(result).to include("2")
      expect(result).to include("10")
    end
  end

  describe "#validate_queue_name!" do
    it "does not raise for valid queue names" do
      expect { helper.validate_queue_name!("default") }.not_to raise_error
    end

    it "does not raise for names with hyphens and dots" do
      expect { helper.validate_queue_name!("my-queue.v2") }.not_to raise_error
    end

    it "halts for path traversal" do
      expect { helper.validate_queue_name!("../evil") }.to raise_error(UncaughtThrowError)
    end

    it "halts for nil" do
      expect { helper.validate_queue_name!(nil) }.to raise_error(UncaughtThrowError)
    end

    it "halts for empty string" do
      expect { helper.validate_queue_name!("") }.to raise_error(UncaughtThrowError)
    end
  end

  describe "#rtl?" do
    it "returns false for English" do
      allow(helper).to receive(:locale).and_return("en")
      expect(helper.rtl?).to be false
    end

    it "returns true for Arabic" do
      allow(helper).to receive(:locale).and_return("ar")
      expect(helper.rtl?).to be true
    end

    it "returns true for Hebrew" do
      allow(helper).to receive(:locale).and_return("he")
      expect(helper.rtl?).to be true
    end
  end

  describe "#csrf_token" do
    it "generates and stores a token in the session" do
      token = helper.csrf_token
      expect(token).not_to be_empty
      expect(helper.session[:csrf]).to eq(token)
    end

    it "returns the same token on subsequent calls" do
      expect(helper.csrf_token).to eq(helper.csrf_token)
    end
  end

  describe "#current_page" do
    it "defaults to page 0 and per_page 25" do
      page, per_page = helper.current_page
      expect(page).to eq(0)
      expect(per_page).to eq(25)
    end

    it "converts 1-indexed page param to 0-indexed" do
      helper.test_params = {"page" => "3"}
      page, = helper.current_page
      expect(page).to eq(2)
    end

    it "clamps per_page to 250 maximum" do
      helper.test_params = {"per_page" => "9999"}
      _, per_page = helper.current_page
      expect(per_page).to eq(250)
    end

    it "clamps per_page to 1 minimum" do
      helper.test_params = {"per_page" => "0"}
      _, per_page = helper.current_page
      expect(per_page).to eq(1)
    end

    it "clamps page to 0 minimum" do
      helper.test_params = {"page" => "-5"}
      page, = helper.current_page
      expect(page).to eq(0)
    end
  end

  describe "#job_display_class" do
    it "returns the job class for regular workers" do
      job = {"class" => "MyWorker", "args" => [1]}
      expect(helper.job_display_class(job)).to eq("MyWorker")
    end

    it "returns the inner job_class for ActiveJob wrappers" do
      job = {
        "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
        "args"  => [{"job_class" => "MyJob", "arguments" => [1]}]
      }
      expect(helper.job_display_class(job)).to eq("MyJob")
    end

    it "falls back to wrapper class when inner arg is not a hash" do
      job = {
        "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
        "args"  => ["not_a_hash"]
      }
      expect(helper.job_display_class(job)).to eq("ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper")
    end
  end

  describe "#raw_args" do
    it "returns args for regular workers" do
      job = {"class" => "MyWorker", "args" => [1, "hello"]}
      expect(helper.raw_args(job)).to eq([1, "hello"])
    end

    it "extracts inner arguments for ActiveJob wrappers" do
      job = {
        "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
        "args"  => [{"job_class" => "MyJob", "arguments" => [42, "test"]}]
      }
      expect(helper.raw_args(job)).to eq([42, "test"])
    end

    it "strips _aj_ metadata keys from ActiveJob arguments" do
      job = {
        "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
        "args"  => [{"job_class" => "MyJob", "arguments" => [{"_aj_globalid" => "gid://...", "name" => "Alice"}]}]
      }
      result = helper.raw_args(job)
      expect(result).to eq(["Alice"])
    end
  end

  describe "#clean_aj_args" do
    it "strips _aj_ keys, and unwraps the remaining single value" do
      # {"_aj_globalid" => ..., "name" => "Alice"} → strip → {"name" => "Alice"} → unwrap → "Alice"
      result = helper.clean_aj_args({"_aj_globalid" => "gid://...", "name" => "Alice"})
      expect(result).to eq("Alice")
    end

    it "unwraps a single-value hash to its value" do
      expect(helper.clean_aj_args({"value" => 42})).to eq(42)
    end

    it "preserves multi-key hashes as hashes" do
      result = helper.clean_aj_args({"a" => 1, "b" => 2})
      expect(result).to eq({"a" => 1, "b" => 2})
    end

    it "recurses into arrays" do
      result = helper.clean_aj_args([{"_aj_x" => "y", "val" => 1}])
      expect(result).to eq([1])
    end

    it "passes through scalars unchanged" do
      expect(helper.clean_aj_args(42)).to eq(42)
      expect(helper.clean_aj_args("str")).to eq("str")
    end
  end

  describe "#display_args" do
    it "returns a JSON string of args" do
      job = {"class" => "MyWorker", "args" => [1, "hello"]}
      expect(helper.display_args(job)).to eq('[1,"hello"]')
    end

    it "truncates very long args" do
      job = {"class" => "MyWorker", "args" => ["x" * 300]}
      result = helper.display_args(job)
      expect(result.length).to be <= 202
      expect(result).to end_with("…")
    end
  end

  describe "#format_args_short" do
    it "formats array args as truncated JSON" do
      job = {"class" => "MyWorker", "args" => [1, 2, 3]}
      expect(helper.format_args_short(job)).to eq("[1,2,3]")
    end

    it "formats hash args as key: value pairs" do
      job = {"class" => "MyWorker", "args" => [{"user_id" => 99, "action" => "sync"}]}
      result = helper.format_args_short(job)
      expect(result).to include("user_id")
      expect(result).to include("99")
    end
  end

  describe "#query_string" do
    let(:helper_with_qs) do
      Class.new do
        include SideBro::WebHelpers

        def request
          @request ||= Rack::Request.new(
            "rack.input"     => StringIO.new,
            "rack.session"   => {},
            "REQUEST_METHOD" => "GET",
            "PATH_INFO"      => "/queues/default",
            "SCRIPT_NAME"    => "",
            "QUERY_STRING"   => "page=2&per_page=25"
          )
        end

        def session; request.env["rack.session"]; end
        def params; request.params; end
        def halt(code); throw :halt, code; end
      end.new
    end

    it "preserves existing params" do
      result = helper_with_qs.query_string
      expect(result).to include("page=2")
      expect(result).to include("per_page=25")
    end

    it "merges overrides" do
      params = Rack::Utils.parse_query(helper_with_qs.query_string("page" => "3"))
      expect(params["page"]).to eq("3")
      expect(params["per_page"]).to eq("25")
    end

    it "removes keys with nil values" do
      params = Rack::Utils.parse_query(helper_with_qs.query_string("page" => nil))
      expect(params).not_to have_key("page")
      expect(params["per_page"]).to eq("25")
    end

    it "returns empty string when no params" do
      h = Class.new do
        include SideBro::WebHelpers
        def request
          @request ||= Rack::Request.new("rack.input" => StringIO.new, "rack.session" => {}, "QUERY_STRING" => "")
        end
        def session; request.env["rack.session"]; end
        def params; request.params; end
        def halt(code); throw :halt, code; end
      end.new
      expect(h.query_string).to eq("")
    end
  end
end
