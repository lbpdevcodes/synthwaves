require "rails_helper"

RSpec.describe "Folders", type: :request do
  let(:user) { create(:user) }
  let(:modal) { {"Turbo-Frame" => "modal"} }

  before { login_user(user) }

  describe "GET /folders/new" do
    it "returns success" do
      get new_folder_path
      expect(response).to have_http_status(:ok)
    end

    it "opens New Collection in the modal" do
      get new_folder_path, headers: modal

      dialog = Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog")
      expect(dialog.text).to include("New Collection")
      form = dialog.at_css("form[action='#{folders_path}']")
      expect(form.at_css("input[name='folder[name]']")).to be_present
      expect(form.at_css("textarea[name='folder[description]']")).to be_present
      expect(form.at_css("input[type='file'][name='folder[cover_image]']")).to be_present
    end

    it "cancels back to the folder it would go inside, on a full page" do
      tv = create(:folder, user: user, name: "TV")

      get new_folder_path(parent_id: tv.id)

      cancel = Nokogiri::HTML(response.body).css("a").find { |link| link.text.strip == "Cancel" }
      expect(cancel["href"]).to eq(folder_path(tv))
    end

    it "offers the user's folders to put it inside, labelled by path, with the one asked for picked" do
      tv = create(:folder, user: user, name: "TV")
      south_park = create(:folder, user: user, parent: tv, name: "South Park")
      create(:folder, name: "Someone else's")

      get new_folder_path(parent_id: south_park.id), headers: modal

      options = Nokogiri::HTML(response.body).css("select[name='folder[parent_id]'] option")
      expect(options.map(&:text)).to eq(["(Top level, under Videos)", "TV", "TV › South Park"])
      expect(options.find { |option| option["selected"] }["value"]).to eq(south_park.id.to_s)
    end
  end

  describe "POST /folders" do
    it "creates an empty folder from the modal and visits it" do
      post folders_path, params: {folder: {name: "The Wire", description: "Baltimore"}}, headers: modal

      folder = user.folders.find_by!(name: "The Wire")
      expect(folder.description).to eq("Baltimore")
      expect(folder.videos).to be_empty
      expect(Nokogiri::HTML(response.body).at_css("turbo-stream[action='visit']")["location"]).to eq(folder_path(folder))
      expect(flash[:notice]).to eq("Created The Wire.")
    end

    it "creates a folder inside another" do
      tv = create(:folder, user: user, name: "TV")

      post folders_path, params: {folder: {name: "South Park", parent_id: tv.id}}, headers: modal

      expect(user.folders.find_by!(name: "South Park").parent).to eq(tv)
    end

    it "keeps the modal open with the error when the name is taken" do
      create(:folder, user: user, name: "The Wire")

      expect {
        post folders_path, params: {folder: {name: "The Wire"}}, headers: modal
      }.not_to change(Folder, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog").text).to include("Name has already been taken")
    end

    context "from a video's folder menu" do
      let(:turbo) { {"Accept" => "text/vnd.turbo-stream.html, text/html"} }
      let(:video) { create(:video, user: user) }

      it "creates the folder, files the video in it, and stays on the page" do
        post folders_path, params: {folder: {name: "The Wire"}, video_ids: [video.id]}, headers: turbo

        expect(video.reload.folder).to eq(user.folders.find_by!(name: "The Wire"))
        expect(Nokogiri::HTML(response.body).at_css("turbo-stream[action='refresh']:not([request-id])")).to be_present
        expect(flash[:notice]).to eq("Created The Wire with 1 video.")
      end

      it "creates nothing and returns 404 for another user's video" do
        expect {
          post folders_path, params: {folder: {name: "The Wire"}, video_ids: [create(:video).id]}, headers: turbo
        }.not_to change(Folder, :count)

        expect(response).to have_http_status(:not_found)
      end

      it "stays on the page and says why when the name is taken" do
        create(:folder, user: user, name: "The Wire")

        post folders_path, params: {folder: {name: "The Wire"}, video_ids: [video.id]}, headers: turbo

        expect(video.reload.folder).to be_nil
        expect(Nokogiri::HTML(response.body).at_css("turbo-stream[action='refresh']")).to be_present
        expect(flash[:notice]).to eq("Couldn't create the collection: Name has already been taken.")
      end
    end
  end

  describe "GET /folders/:id" do
    def doc
      Nokogiri::HTML(response.body)
    end

    it "offers Upload videos, and Edit and Delete under More, each opening in the modal" do
      folder = create(:folder, user: user, name: "The Wire")

      get folder_path(folder)

      expect(doc.at_css("a[href='#{new_folder_upload_path(folder)}']")["data-turbo-frame"]).to eq("modal")
      expect(doc.at_css("a[href='#{new_folder_video_path(folder)}']")["data-turbo-frame"]).to eq("modal")
      expect(doc.at_css("a[href='#{edit_folder_path(folder)}']")["data-turbo-frame"]).to eq("modal")
      delete_form = doc.at_css("form[action='#{folder_path(folder)}']:has(input[value='delete'])")
      expect(delete_form["data-turbo-confirm"]).to eq('Delete "The Wire"?')
    end

    it "lets each video in the folder be taken out of it" do
      folder = create(:folder, user: user, name: "The Wire")
      video = create(:video, user: user, folder: folder)

      get folder_path(folder)

      remove = doc.css("form[action='#{video_folder_path(video)}']").find { |form| form.at_css("input[value='delete']") }
      expect(remove.text).to include("Remove from The Wire")
      expect(remove["data-turbo-frame"]).to eq("_top")
    end

    it "invites an upload when the folder is empty" do
      folder = create(:folder, user: user)

      get folder_path(folder)

      empty = doc.at_css("[data-folder-empty]")
      expect(empty.text).to include("This collection is empty")
      expect(empty.at_css("a[href='#{new_folder_upload_path(folder)}']")["data-turbo-frame"]).to eq("modal")
      expect(empty.at_css("a[href='#{new_folder_video_path(folder)}']")["data-turbo-frame"]).to eq("modal")
    end

    context "with subfolders" do
      let!(:tv) { create(:folder, user: user, name: "TV") }
      let!(:south_park) { create(:folder, user: user, parent: tv, name: "South Park") }

      it "lists them, and counts them in the header" do
        get folder_path(tv)

        expect(doc.at_css("[data-subfolders] a[href='#{folder_path(south_park)}']")).to be_present
        expect(doc.text).to include("1 collection")
      end

      it "is not called empty when it holds only folders" do
        get folder_path(tv)

        expect(doc.at_css("[data-folder-empty]")).to be_nil
      end

      it "goes back to its parent folder" do
        get folder_path(south_park)

        expect(doc.at_css("a[href='#{folder_path(tv)}']").text).to include("Back to TV")
      end
    end

    it "offers New collection under More, opening it inside this one in the modal" do
      folder = create(:folder, user: user)

      get folder_path(folder)

      expect(doc.at_css("a[href='#{new_folder_path(parent_id: folder.id)}']")["data-turbo-frame"]).to eq("modal")
    end

    it "says the videos are processing when none is ready yet" do
      folder = create(:folder, user: user)
      create_list(:video, 2, :processing, user: user, folder: folder)

      get folder_path(folder)

      expect(doc.text).to include("2 videos are processing. They'll appear here when they're ready.")
      expect(doc.at_css("[data-folder-empty]")).to be_nil
    end

    it "says the videos failed when none is ready and none is processing" do
      folder = create(:folder, user: user)
      create(:video, :failed, user: user, folder: folder)

      get folder_path(folder)

      expect(doc.text).to include("1 video in this collection failed to process.")
      expect(doc.at_css("[data-folder-empty]")).to be_nil
    end

    it "returns success for own folder" do
      folder = create(:folder, user: user)
      get folder_path(folder)
      expect(response).to have_http_status(:ok)
    end

    it "shows videos from all seasons" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, season_number: 1, episode_number: 1, title: "Pilot")
      create(:video, user: user, folder: folder, season_number: 2, episode_number: 1, title: "Premiere")

      get folder_path(folder)
      expect(response.body).to include("Pilot")
      expect(response.body).to include("Premiere")
    end

    it "paginates when more than 24 videos" do
      folder = create(:folder, user: user)
      25.times do |i|
        create(:video, user: user, folder: folder, season_number: 1, episode_number: i + 1, title: "Episode #{i + 1}")
      end

      get folder_path(folder)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("page=2")
    end

    it "filters by season" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, season_number: 1, episode_number: 1, title: "S1 Pilot")
      create(:video, user: user, folder: folder, season_number: 2, episode_number: 1, title: "S2 Premiere")

      get folder_path(folder, season: "1")
      expect(response.body).to include("S1 Pilot")
      expect(response.body).not_to include("S2 Premiere")
    end

    it "filters by search query" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, title: "Pilot")
      create(:video, user: user, folder: folder, title: "Finale")

      get folder_path(folder, q: "Pilot")
      expect(response.body).to include("Pilot")
      expect(response.body).not_to include("Finale")
    end

    it "sorts by title" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, title: "Zebra")
      create(:video, user: user, folder: folder, title: "Alpha")

      get folder_path(folder, sort: "title", direction: "asc")
      expect(response).to have_http_status(:ok)
      expect(response.body.index("Alpha")).to be < response.body.index("Zebra")
    end

    it "falls back to default sort for invalid sort param" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder)

      get folder_path(folder, sort: "bogus")
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's folder" do
      other_user = create(:user)
      folder = create(:folder, user: other_user)

      get folder_path(folder)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /folders/:id/edit" do
    it "returns success" do
      folder = create(:folder, user: user)
      get edit_folder_path(folder)
      expect(response).to have_http_status(:ok)
    end

    it "opens Edit in the modal, with a Delete that says where the videos go" do
      folder = create(:folder, user: user, name: "The Wire")
      create_list(:video, 2, user: user, folder: folder)

      get edit_folder_path(folder), headers: modal

      dialog = Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog")
      expect(dialog.at_css("input[name='folder[name]']")["value"]).to eq("The Wire")
      delete_form = dialog.at_css("form[action='#{folder_path(folder)}'][data-turbo-frame='_top']:has(input[value='delete'])")
      expect(delete_form["data-turbo-confirm"]).to eq('Delete "The Wire"? 2 videos in it will stay in your library, under Videos.')
    end

    it "says the contents of a folder inside another move to that folder" do
      tv = create(:folder, user: user, name: "TV")
      south_park = create(:folder, user: user, parent: tv, name: "South Park")
      create(:folder, user: user, parent: south_park, name: "Season 1")
      create_list(:video, 2, user: user, folder: south_park)

      get edit_folder_path(south_park), headers: modal

      delete_form = Nokogiri::HTML(response.body).at_css("form[action='#{folder_path(south_park)}']:has(input[value='delete'])")
      expect(delete_form["data-turbo-confirm"]).to eq('Delete "South Park"? 1 collection and 2 videos in it will move to TV.')
    end
  end

  describe "PATCH /folders/:id" do
    it "updates the folder" do
      folder = create(:folder, user: user, name: "Old Name")
      patch folder_path(folder), params: {folder: {name: "New Name", description: "Updated"}}

      folder.reload
      expect(folder.name).to eq("New Name")
      expect(folder.description).to eq("Updated")
      expect(response).to redirect_to(folder_path(folder))
    end

    it "rejects blank name" do
      folder = create(:folder, user: user)
      patch folder_path(folder), params: {folder: {name: ""}}
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refreshes the page under the modal after an edit" do
      folder = create(:folder, user: user)

      patch folder_path(folder), params: {folder: {name: "Renamed"}}, headers: modal

      expect(Nokogiri::HTML(response.body).at_css("turbo-stream[action='refresh']:not([request-id])")).to be_present
      expect(folder.reload.name).to eq("Renamed")
    end

    it "moves the folder inside another" do
      tv = create(:folder, user: user, name: "TV")
      south_park = create(:folder, user: user, name: "South Park")

      patch folder_path(south_park), params: {folder: {parent_id: tv.id}}, headers: modal

      expect(south_park.reload.parent).to eq(tv)
    end

    it "keeps the modal open and says why when the move would put the folder inside itself" do
      tv = create(:folder, user: user, name: "TV")
      south_park = create(:folder, user: user, parent: tv, name: "South Park")

      patch folder_path(tv), params: {folder: {parent_id: south_park.id}}, headers: modal

      expect(response).to have_http_status(:unprocessable_content)
      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog").text)
        .to include("TV can't go inside itself or anything inside it")
      expect(tv.reload.parent).to be_nil
    end
  end

  describe "DELETE /folders/:id" do
    it "deletes the folder but keeps videos" do
      folder = create(:folder, user: user)
      video = create(:video, user: user, folder: folder)

      expect { delete folder_path(folder) }.to change(Folder, :count).by(-1)
      expect(Video.exists?(video.id)).to be true
      expect(video.reload.folder_id).to be_nil
      expect(response).to redirect_to(tv_path(tab: "videos"))
    end

    it "says how many videos went back to Videos when deleted from its own page" do
      folder = create(:folder, user: user, name: "The Wire")
      create_list(:video, 2, user: user, folder: folder)

      delete folder_path(folder), headers: {"Referer" => folder_url(folder)}

      expect(response).to redirect_to(tv_path(tab: "videos"))
      expect(flash[:notice]).to eq("Deleted The Wire. 2 videos moved back to Videos.")
    end

    it "names only the folder when it held no videos" do
      folder = create(:folder, user: user, name: "The Wire")

      delete folder_path(folder)

      expect(flash[:notice]).to eq("Deleted The Wire.")
    end

    context "inside another folder" do
      let!(:tv) { create(:folder, user: user, name: "TV") }
      let!(:south_park) { create(:folder, user: user, parent: tv, name: "South Park") }

      it "moves its contents up, says where, and returns to the parent from its own page" do
        create(:folder, user: user, parent: south_park, name: "Season 1")
        create_list(:video, 2, user: user, folder: south_park)

        delete folder_path(south_park), headers: {"Referer" => folder_url(south_park)}

        expect(response).to redirect_to(folder_path(tv))
        expect(flash[:notice]).to eq("Deleted South Park. 1 collection and 2 videos moved to TV.")
      end

      it "stays put and says why when a subfolder's name is taken in the parent" do
        create(:folder, user: user, parent: tv, name: "Season 1")
        create(:folder, user: user, parent: south_park, name: "Season 1")

        expect { delete folder_path(south_park) }.not_to change(Folder, :count)

        expect(response).to redirect_to(folder_path(south_park))
        expect(flash[:alert]).to eq("Can't delete South Park: TV already has one named Season 1.")
      end
    end

    it "counts the collections that went back to Videos" do
      tv = create(:folder, user: user, name: "TV")
      create(:folder, user: user, parent: tv, name: "South Park")

      delete folder_path(tv)

      expect(flash[:notice]).to eq("Deleted TV. 1 collection moved back to Videos.")
    end
  end
end
