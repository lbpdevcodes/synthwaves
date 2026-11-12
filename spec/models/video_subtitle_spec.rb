require "rails_helper"

RSpec.describe VideoSubtitle, type: :model do
  subject { build(:video_subtitle) }

  describe "associations" do
    it { should belong_to(:video) }
  end

  describe "validations" do
    it { should validate_presence_of(:label) }
    it { should validate_uniqueness_of(:label).scoped_to(:video_id) }
    it { should validate_inclusion_of(:kind).in_array(%w[subtitles captions]) }
    it { should validate_presence_of(:vtt) }
  end
end
