# frozen_string_literal: true

RSpec.describe SimpleLock do
  it "has a version number" do
    expect(SimpleLock::VERSION).not_to be nil
  end

  describe "#config" do
    subject { SimpleLock.config }

    it { is_expected.to be_a(SimpleLock::Config) }
    it {
      is_expected.to have_attributes(
        key_prefix: "simple_lock:",
        retry_count: 3,
        retry_delay: 200,
        retry_jitter: 50,
        retry_proc: nil
      )
    }
  end

  describe "#client" do
    subject { SimpleLock.client }

    it { is_expected.to be_a(SimpleLock::Redis) }
  end

  describe "#client=" do
    let(:redis_url) { "redis://username:password@redis-server.example.com:6379/0" }

    around do |example|
      SimpleLock.with(client: redis_url) do
        example.run
      end
    end

    it "sets the client" do
      expect(SimpleLock.client).to be_a(SimpleLock::Redis)
      expect(SimpleLock.client.connection).to eq(
        {
          host: "redis-server.example.com",
          port: 6379,
          db: 0,
          id: "redis://redis-server.example.com:6379/0",
          location: "redis-server.example.com:6379"
        }
      )
    end
  end

  describe "#lock" do
    let(:key) { "foo" }
    let(:ttl) { 1000 }

    subject { SimpleLock.lock(key, ttl) }

    before do
      allow(SimpleLock).to receive(:safe_exec_script).and_return("OK")
    end

    it { is_expected.to be(true) }
  end

  describe "#unlock" do
    let(:key) { "foo" }

    before do
      allow(SimpleLock).to receive(:safe_exec_script).and_return("OK")

      SimpleLock.lock(key, 1000)
    end

    it { expect { SimpleLock.unlock(key) }.not_to raise_error }
  end

  describe "#load_scripts" do
    before do
      allow(SimpleLock.client).to receive(:script)
    end

    it "loads the scripts" do
      expect(SimpleLock.client).to receive(:script).with(
        "load", "return redis.call('set', KEYS[1], 1, 'NX', 'PX', ARGV[1])"
      )
      expect(SimpleLock.client).to receive(:script).with(
        "load", "redis.call('del', KEYS[1])"
      )

      SimpleLock.load_scripts
    end
  end

  describe "#backoff_for_attempt" do
    subject { SimpleLock.backoff_for_attempt(1) }

    before do
      allow(SimpleLock).to receive(:rand).with(50).and_return(10)
    end

    it { is_expected.to eq(0.21) }

    context "with retry_proc" do
      before do
        SimpleLock.config.retry_proc = ->(attempt) { attempt * 150 }
      end

      it { is_expected.to eq(0.16) }
    end
  end
end
