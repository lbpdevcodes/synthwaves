require "rails_helper"

RSpec.describe TrackActions::Component, type: :component do
  include ViewComponent::TestHelpers
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let(:track) { create(:track, user: user) }

  before { Current.session = user.sessions.create!(user_agent: "rspec", ip_address: "127.0.0.1") }
  after { Current.reset }

  def render_actions(favorited: false, for_track: track)
    render_inline(described_class.new(track: for_track, favorited: favorited))
  end

  it "links to the download when the track has audio" do
    expect(render_actions.at_css("a[href='#{download_track_path(track)}']")).to be_present
  end

  it "omits the download when the track has no audio" do
    youtube_track = create(:track, :youtube, user: user)
    expect(render_actions(for_track: youtube_track).at_css("a[href='#{download_track_path(youtube_track)}']")).to be_nil
  end

  it "offers to un-favorite a favorited track" do
    favorite = create(:favorite, user: user, favorable: track)
    form = render_actions(favorited: true).at_css("form[action='#{favorite_path(favorite)}']")
    expect(form.at_css("input[name='_method'][value='delete']")).to be_present
  end

  it "offers to favorite a track that is not a favorite" do
    form = render_actions.at_css("form[method='post'][action^='#{favorites_path}?']")
    expect(form["action"]).to include("favorable_type=Track", "favorable_id=#{track.id}")
  end

  it "offers to add the track to a playlist" do
    expect(render_actions.at_css("button[title='Add to playlist']")).to be_present
  end
end
