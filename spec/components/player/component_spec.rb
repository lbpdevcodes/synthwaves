require "rails_helper"

RSpec.describe Player::Component, type: :component do
  include ViewComponent::TestHelpers

  context "when unauthenticated" do
    before do
      allow(vc_test_controller).to receive(:authenticated?).and_return(nil)
    end

    it "does not render" do
      result = render_inline(described_class.new)
      expect(result.to_html.strip).to be_empty
    end
  end

  context "when authenticated" do
    let(:user) { create(:user) }

    before do
      allow(vc_test_controller).to receive(:authenticated?).and_return(user)
    end

    def rendered
      render_inline(described_class.new)
    end

    it "renders #player-bar with data-turbo-permanent" do
      html = rendered
      player_bar = html.at_css("#player-bar")
      expect(player_bar).to be_present
      expect(player_bar["data-turbo-permanent"]).not_to be_nil
    end

    it "renders #queue-panel-container" do
      expect(rendered.at_css("#queue-panel-container")).to be_present
    end

    it "renders #visualizer-panel-container" do
      expect(rendered.at_css("#visualizer-panel-container")).to be_present
    end

    it "renders #fullscreen-now-playing" do
      expect(rendered.at_css("#fullscreen-now-playing")).to be_present
    end

    it "renders keyboard shortcuts modal" do
      expect(rendered.at_css("[data-keyboard-shortcuts-target='helpModal']")).to be_present
    end

    it "includes player and queue Stimulus controllers" do
      player_bar = rendered.at_css("#player-bar")
      expect(player_bar["data-controller"]).to include("player")
      expect(player_bar["data-controller"]).to include("queue")
    end

    it "includes play history URL data attribute" do
      player_bar = rendered.at_css("#player-bar")
      expect(player_bar["data-player-play-history-url-value"]).to eq("/play_histories")
    end

    it "renders the equalizer button and menu" do
      html = rendered
      expect(html.at_css("button[data-action='player#toggleEqMenu'][data-player-target='eqButton']")).to be_present
      expect(html.at_css("[data-player-target='eqMenu']")).to be_present
      expect(html.at_css("button[data-action='player#toggleEqEnabled'][data-player-target='eqToggle']")).to be_present
    end

    it "renders a slider for each EQ band" do
      bands = rendered.css("[data-player-target='eqMenu'] input[type='range'][data-band]")
      expect(bands.map { |slider| slider["data-band"] }).to eq(%w[60 250 1000 4000 12000])
    end

    it "renders EQ presets" do
      presets = rendered.css("button[data-action='player#applyEqPreset']")
      expect(presets.map { |button| button["data-preset"] }).to eq(%w[flat bass vocal treble])
    end

    it "opens fullscreen now playing when the track info is tapped" do
      html = rendered
      artwork = html.at_css("[data-player-target='artwork']")
      info = artwork.ancestors("div").find { |d| d["data-action"].to_s.include?("click->player#toggleFullscreen") }
      expect(info).to be_present
      expect(info["class"]).to include("cursor-pointer")
    end

    it "marks secondary controls as hidden on touch devices" do
      html = rendered
      sleep_timer = html.at_css("[data-controller='sleep-timer']")
      visualizer = html.at_css("button[data-action='player#toggleVisualizer']")
      crossfade = html.at_css("button[data-player-target='crossfadeButton']").parent
      expect(sleep_timer["class"]).to include("coarse-hide")
      expect(visualizer["class"]).to include("coarse-hide")
      expect(crossfade["class"]).to include("coarse-hide")
    end
  end
end
