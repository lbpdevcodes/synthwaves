require "rails_helper"

RSpec.describe Maintenance::VideoLibraryBackfillTask do
  let(:user) { create(:user) }
  let(:task) { described_class.new.tap { |task| task.assign_attributes(user_id: user.id, genre_folders: "Action, Animated") } }

  describe "#collection" do
    it "walks the user's videos only" do
      own = create(:video, user: user)
      create(:video, user: create(:user))

      expect(task.collection).to eq([own])
    end
  end

  describe "#process" do
    it "fills the video from the genre folder named for the run" do
      action = create(:folder, user: user, name: "Action")
      film = create(:video, user: user, folder: action)

      task.process(film)

      expect(film.reload).to have_attributes(video_type: "movie", genre_names: %w[action])
    end

    it "leaves a video with nothing to fill as it is" do
      film = create(:video, user: user, video_type: "movie")

      expect { task.process(film) }.not_to change { film.reload.updated_at }
    end
  end
end
