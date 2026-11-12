require "rails_helper"

RSpec.describe FolderMenu::Component, type: :component do
  include ViewComponent::TestHelpers

  let(:user) { create(:user) }
  let(:the_wire) { create(:folder, user: user, name: "The Wire") }
  let(:deadwood) { create(:folder, user: user, name: "Deadwood") }

  def render_menu(video)
    render_inline(described_class.new(video: video, folders: [deadwood, the_wire]))
  end

  def move_form(html, folder)
    html.css("form[action='/videos/#{video.id}/folder']").find { |form| form.at_css("input[name='folder_id'][value='#{folder.id}']") }
  end

  context "for a loose video" do
    let(:video) { create(:video, user: user, title: "Pilot") }

    it "names the video in the trigger's label" do
      expect(render_menu(video).at_css("button[data-action='dropdown#toggle']").text.strip).to eq("Move Pilot to a collection")
    end

    it "offers a move into each folder, as a full-page Turbo submission" do
      html = render_menu(video)

      [deadwood, the_wire].each do |folder|
        form = move_form(html, folder)
        expect(form.at_css("input[name='_method'][value='patch']")).to be_present
        expect(form["data-turbo-frame"]).to eq("_top")
      end
    end

    it "offers a new folder named in place, carrying the video" do
      form = render_menu(video).at_css("form[action='/folders']")

      expect(form.at_css("input[type='hidden'][name='video_ids[]'][value='#{video.id}']")).to be_present
      expect(form.at_css("input[name='folder[name]'][required]")).to be_present
      expect(form["data-turbo-frame"]).to eq("_top")
    end

    it "offers no removal" do
      expect(render_menu(video).text).not_to include("Remove from")
    end
  end

  context "for a video in a folder" do
    let(:video) { create(:video, user: user, folder: the_wire) }

    it "marks the current folder instead of offering a move into it" do
      html = render_menu(video)

      expect(move_form(html, the_wire)).to be_nil
      expect(html.at_css("[aria-current='true']").text).to include("The Wire")
      expect(move_form(html, deadwood)).to be_present
    end

    it "offers to remove it from the folder" do
      html = render_menu(video)

      remove = html.css("form[action='/videos/#{video.id}/folder']").find { |form| form.at_css("input[name='_method'][value='delete']") }
      expect(remove.text).to include("Remove from The Wire")
      expect(remove["data-turbo-frame"]).to eq("_top")
    end
  end
end
