# frozen_string_literal: true

RSpec.describe SideBro::WebHelpers do
  let(:helper) do
    Class.new do
      include SideBro::WebHelpers

      def request
        @request ||= Rack::Request.new(
          "rack.input" => StringIO.new,
          "rack.session" => {},
          "REQUEST_METHOD" => "GET",
          "PATH_INFO" => "/",
          "SCRIPT_NAME" => ""
        )
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
  end

  describe "#truncate" do
    it "returns the string unchanged when under the limit" do
      expect(helper.truncate("hello", 10)).to eq("hello")
    end

    it "truncates long strings with ellipsis" do
      result = helper.truncate("a" * 210, 200)
      expect(result.length).to be <= 202 # 200 + ellipsis char
      expect(result).to end_with("…")
    end
  end

  describe "#relative_time" do
    it "formats seconds" do
      expect(helper.relative_time(Time.now - 30)).to eq("30s")
    end

    it "formats minutes" do
      expect(helper.relative_time(Time.now - 130)).to eq("2m")
    end

    it "returns empty string for nil" do
      expect(helper.relative_time(nil)).to eq("")
    end
  end

  describe "#t" do
    it "returns the English translation" do
      expect(helper.t(:dashboard)).to eq("Dashboard")
    end

    it "falls back to the key name for unknown keys" do
      expect(helper.t(:nonexistent_key_xyz)).to eq("nonexistent_key_xyz")
    end
  end

  describe "#validate_queue_name!" do
    it "does not raise for valid queue names" do
      expect { helper.validate_queue_name!("default") }.not_to raise_error
    end

    it "halts for invalid queue names" do
      expect { helper.validate_queue_name!("../evil") }.to raise_error(UncaughtThrowError)
    end
  end
end
