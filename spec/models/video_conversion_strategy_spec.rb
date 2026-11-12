require "rails_helper"

RSpec.describe VideoConversionStrategy do
  describe ".needs_audio_normalization?" do
    it "returns false for nil audio_channels (no audio stream)" do
      metadata = {audio_channels: nil}
      expect(described_class.needs_audio_normalization?(metadata)).to be false
    end

    it "returns false for mono audio" do
      metadata = {audio_channels: 1}
      expect(described_class.needs_audio_normalization?(metadata)).to be false
    end

    it "returns false for stereo audio" do
      metadata = {audio_channels: 2}
      expect(described_class.needs_audio_normalization?(metadata)).to be false
    end

    it "returns true for 6-channel surround audio" do
      metadata = {audio_channels: 6}
      expect(described_class.needs_audio_normalization?(metadata)).to be true
    end

    it "returns true for 8-channel audio" do
      metadata = {audio_channels: 8}
      expect(described_class.needs_audio_normalization?(metadata)).to be true
    end
  end
end
