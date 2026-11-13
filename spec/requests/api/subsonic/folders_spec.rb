require "rails_helper"

RSpec.describe "Subsonic Folders API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "getFolders" do
    it "returns all folders with video counts" do
      folder1 = create(:folder, user: user, name: "Series A")
      folder2 = create(:folder, user: user, name: "Series B")
      create(:video, user: user, folder: folder1)
      create(:video, user: user, folder: folder1)
      create(:video, user: user, folder: folder2)
      create(:video, :processing, user: user, folder: folder2)

      get "/api/rest/getFolders", params: auth_params

      json = JSON.parse(response.body)
      folders = json["subsonic-response"]["folders"]["folder"]
      expect(folders.length).to eq(2)

      a = folders.find { |f| f["name"] == "Series A" }
      b = folders.find { |f| f["name"] == "Series B" }
      expect(a["videoCount"]).to eq(2)
      expect(b["videoCount"]).to eq(1)
    end

    it "lists folders by name, with each one's description and creation time" do
      create(:folder, user: user, name: "Zeta", description: "The last one")
      alpha = create(:folder, user: user, name: "Alpha")

      get "/api/rest/getFolders", params: auth_params

      folders = JSON.parse(response.body)["subsonic-response"]["folders"]["folder"]
      expect(folders.map { |f| f["name"] }).to eq(%w[Alpha Zeta])
      expect(folders.last["description"]).to eq("The last one")
      expect(folders.first).not_to have_key("description")
      expect(folders.first["created"]).to eq(alpha.created_at.iso8601)
    end

    it "does not return other users' folders" do
      other_user = create(:user)
      create(:folder, user: other_user, name: "Other folder")
      create(:folder, user: user, name: "My folder")

      get "/api/rest/getFolders", params: auth_params

      json = JSON.parse(response.body)
      folders = json["subsonic-response"]["folders"]["folder"]
      expect(folders.length).to eq(1)
      expect(folders.first["name"]).to eq("My folder")
    end
  end

  describe "getFolder" do
    it "returns folder with its videos" do
      folder = create(:folder, user: user, name: "My Series")
      create(:video, user: user, folder: folder, title: "Ep 1", season_number: 1, episode_number: 1)
      create(:video, user: user, folder: folder, title: "Ep 2", season_number: 1, episode_number: 2)
      create(:video, :processing, user: user, folder: folder, title: "Ep 3")

      get "/api/rest/getFolder", params: auth_params.merge(id: folder.id)

      json = JSON.parse(response.body)
      f = json["subsonic-response"]["folder"]
      expect(f["id"]).to eq(folder.id.to_s)
      expect(f["name"]).to eq("My Series")
      expect(f["video"].length).to eq(2)
      expect(f["video"].map { |v| v["title"] }).to eq(["Ep 1", "Ep 2"])
    end

    it "includes the description, the ready video count and the creation time" do
      folder = create(:folder, user: user, name: "My Series", description: "Two seasons")
      create(:video, user: user, folder: folder)
      create(:video, :processing, user: user, folder: folder)

      get "/api/rest/getFolder", params: auth_params.merge(id: folder.id)

      f = JSON.parse(response.body)["subsonic-response"]["folder"]
      expect(f["description"]).to eq("Two seasons")
      expect(f["videoCount"]).to eq(1)
      expect(f["created"]).to eq(folder.created_at.iso8601)
    end

    it "returns error for nonexistent folder" do
      get "/api/rest/getFolder", params: auth_params.merge(id: 999999)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end
  end

  describe "createFolder" do
    def subsonic_response
      JSON.parse(response.body)["subsonic-response"]
    end

    it "replies in XML when the client doesn't ask for JSON" do
      get "/api/rest/createFolder", params: auth_params.except(:f).merge(name: "The Wire")

      doc = Nokogiri::XML(response.body)
      expect(doc.at("subsonic-response")["status"]).to eq("ok")
      expect(doc.at("folder")["name"]).to eq("The Wire")
    end

    it "creates a folder and replies with it" do
      get "/api/rest/createFolder", params: auth_params.merge(name: "The Wire", description: "Baltimore")

      folder = user.folders.find_by!(name: "The Wire")
      expect(folder.description).to eq("Baltimore")
      expect(subsonic_response["status"]).to eq("ok")
      expect(subsonic_response["folder"]).to include("id" => folder.id.to_s, "name" => "The Wire", "videoCount" => 0, "video" => [])
    end

    it "answers error 10 when the name is missing" do
      get "/api/rest/createFolder", params: auth_params

      expect(subsonic_response["error"]).to eq("code" => 10, "message" => "Required parameter is missing: name")
    end

    it "answers error 10 when the name is blank" do
      expect { get "/api/rest/createFolder", params: auth_params.merge(name: " ") }.not_to change(Folder, :count)

      expect(subsonic_response["error"]["code"]).to eq(10)
    end

    it "answers error 0 with the reason when the name is taken" do
      create(:folder, user: user, name: "The Wire")

      expect { get "/api/rest/createFolder", params: auth_params.merge(name: "The Wire") }.not_to change(Folder, :count)

      expect(response).to have_http_status(:ok)
      expect(subsonic_response["error"]).to eq("code" => 0, "message" => "Name has already been taken")
    end

    it "moves every video the client repeats without brackets into the new folder" do
      first = create(:video, user: user)
      second = create(:video, user: user)

      get "/api/rest/createFolder?#{auth_params.merge(name: "The Wire").to_query}&videoId=#{first.id}&videoId=#{second.id}"

      expect(user.folders.find_by!(name: "The Wire").videos).to contain_exactly(first, second)
    end

    it "reads repeated video ids from a form POST body too" do
      first = create(:video, user: user)
      second = create(:video, user: user)

      post "/api/rest/createFolder", params: "#{auth_params.merge(name: "The Wire").to_query}&videoId=#{first.id}&videoId=#{second.id}",
        headers: {"CONTENT_TYPE" => "application/x-www-form-urlencoded"}

      expect(user.folders.find_by!(name: "The Wire").videos).to contain_exactly(first, second)
    end

    it "creates nothing and answers 70 when a video isn't the user's" do
      mine = create(:video, user: user)

      expect {
        get "/api/rest/createFolder?#{auth_params.merge(name: "The Wire").to_query}&videoId=#{mine.id}&videoId=#{create(:video).id}"
      }.not_to change(Folder, :count)

      expect(subsonic_response["error"]).to eq("code" => 70, "message" => "Video not found")
      expect(mine.reload.folder).to be_nil
    end
  end

  describe "updateFolder" do
    let(:folder) { create(:folder, user: user, name: "The Wire", description: "Baltimore") }

    def subsonic_response
      JSON.parse(response.body)["subsonic-response"]
    end

    def update_query(extra)
      "/api/rest/updateFolder?#{auth_params.merge(id: folder.id).to_query}&#{extra}"
    end

    it "renames and re-describes the folder and replies with it" do
      get "/api/rest/updateFolder", params: auth_params.merge(id: folder.id, name: "The Wire (HBO)", description: "Five seasons")

      expect(folder.reload).to have_attributes(name: "The Wire (HBO)", description: "Five seasons")
      expect(subsonic_response["folder"]).to include("name" => "The Wire (HBO)", "description" => "Five seasons")
    end

    it "clears the description when the client sends it empty, and keeps the name it didn't send" do
      get "/api/rest/updateFolder", params: auth_params.merge(id: folder.id, description: "")

      expect(folder.reload.description).to be_blank
      expect(folder.name).to eq("The Wire")
      expect(subsonic_response["folder"]).not_to have_key("description")
    end

    it "adds and removes the videos the client repeats without brackets" do
      added = create_list(:video, 2, user: user)
      removed = create_list(:video, 2, user: user, folder: folder)
      kept = create(:video, user: user, folder: folder)

      get update_query((added.map { |v| "videoIdToAdd=#{v.id}" } + removed.map { |v| "videoIdToRemove=#{v.id}" }).join("&"))

      expect(folder.videos.reload).to contain_exactly(*added, kept)
      expect(removed.map { |v| v.reload.folder }).to eq([nil, nil])
    end

    it "answers error 10 when the id is missing" do
      get "/api/rest/updateFolder", params: auth_params.merge(name: "Renamed")

      expect(subsonic_response["error"]).to eq("code" => 10, "message" => "Required parameter is missing: id")
    end

    it "answers 70 for another user's folder and leaves it alone" do
      other = create(:folder, name: "Theirs")

      get "/api/rest/updateFolder", params: auth_params.merge(id: other.id, name: "Mine now")

      expect(subsonic_response["error"]).to eq("code" => 70, "message" => "Folder not found")
      expect(other.reload.name).to eq("Theirs")
    end

    it "changes nothing and answers 70 when a video to add isn't the user's" do
      mine = create(:video, user: user)

      get update_query("name=Renamed&videoIdToAdd=#{mine.id}&videoIdToAdd=#{create(:video).id}")

      expect(subsonic_response["error"]).to eq("code" => 70, "message" => "Video not found")
      expect(folder.reload.name).to eq("The Wire")
      expect(mine.reload.folder).to be_nil
    end

    it "answers error 0 with the reason when the new name is blank" do
      get "/api/rest/updateFolder", params: auth_params.merge(id: folder.id, name: "")

      expect(subsonic_response["error"]).to eq("code" => 0, "message" => "Name can't be blank")
      expect(folder.reload.name).to eq("The Wire")
    end
  end

  describe "deleteFolder" do
    def subsonic_response
      JSON.parse(response.body)["subsonic-response"]
    end

    it "deletes the folder and keeps its videos" do
      folder = create(:folder, user: user)
      video = create(:video, user: user, folder: folder)

      get "/api/rest/deleteFolder", params: auth_params.merge(id: folder.id)

      expect(subsonic_response["status"]).to eq("ok")
      expect(Folder.exists?(folder.id)).to be false
      expect(video.reload.folder).to be_nil
    end

    it "answers error 10 when the id is missing" do
      get "/api/rest/deleteFolder", params: auth_params

      expect(subsonic_response["error"]).to eq("code" => 10, "message" => "Required parameter is missing: id")
    end

    it "answers 70 for another user's folder and keeps it" do
      other = create(:folder)

      get "/api/rest/deleteFolder", params: auth_params.merge(id: other.id)

      expect(subsonic_response["error"]).to eq("code" => 70, "message" => "Folder not found")
      expect(Folder.exists?(other.id)).to be true
    end
  end

  describe "getFolderCover" do
    def attach_image(attachment, name)
      attachment.attach(io: StringIO.new("image"), filename: name, content_type: "image/jpeg")
    end

    it "redirects to the folder's cover image" do
      folder = create(:folder, user: user)
      attach_image(folder.cover_image, "cover.jpg")

      get "/api/rest/getFolderCover", params: auth_params.merge(id: folder.id)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("cover.jpg")
    end

    it "redirects to a resized copy when the client asks for a size" do
      folder = create(:folder, user: user)
      attach_image(folder.cover_image, "cover.jpg")

      get "/api/rest/getFolderCover", params: auth_params.merge(id: folder.id, size: 200)

      expect(response.location).to include("/representations/")
    end

    it "falls back to the first ready video's thumbnail" do
      folder = create(:folder, user: user)
      attach_image(create(:video, user: user, folder: folder).thumbnail, "thumb.jpg")

      get "/api/rest/getFolderCover", params: auth_params.merge(id: folder.id)

      expect(response.location).to include("thumb.jpg")
    end

    it "returns 404 when the folder has no cover and no thumbnail" do
      get "/api/rest/getFolderCover", params: auth_params.merge(id: create(:folder, user: user).id)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's folder" do
      folder = create(:folder)
      attach_image(folder.cover_image, "cover.jpg")

      get "/api/rest/getFolderCover", params: auth_params.merge(id: folder.id)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "nesting" do
    let!(:tv) { create(:folder, user: user, name: "TV") }
    let!(:south_park) { create(:folder, user: user, parent: tv, name: "South Park") }

    def subsonic_response
      JSON.parse(response.body)["subsonic-response"]
    end

    def subsonic_error
      subsonic_response["error"]
    end

    it "gives each folder inside another its parentId in getFolders, and none to a top-level one" do
      get "/api/rest/getFolders", params: auth_params

      entries = subsonic_response.dig("folders", "folder").index_by { |entry| entry["name"] }
      expect(entries["South Park"]["parentId"]).to eq(tv.id.to_s)
      expect(entries["TV"]).not_to have_key("parentId")
    end

    it "gives parentId as an XML attribute" do
      get "/api/rest/getFolder", params: auth_params.except(:f).merge(id: south_park.id)

      expect(Nokogiri::XML(response.body).at("folder")["parentId"]).to eq(tv.id.to_s)
    end

    it "creates a folder inside the one parentId names" do
      get "/api/rest/createFolder", params: auth_params.merge(name: "Season 1", parentId: south_park.id)

      expect(user.folders.find_by!(name: "Season 1").parent).to eq(south_park)
      expect(subsonic_response["folder"]["parentId"]).to eq(south_park.id.to_s)
    end

    it "creates nothing when parentId names another user's folder" do
      someone_elses = create(:folder)

      expect {
        get "/api/rest/createFolder", params: auth_params.merge(name: "Season 1", parentId: someone_elses.id)
      }.not_to change(Folder, :count)

      expect(subsonic_error).to eq("code" => 70, "message" => "Folder not found")
    end

    it "moves a folder inside the one parentId names" do
      movies = create(:folder, user: user, name: "Movies")

      get "/api/rest/updateFolder", params: auth_params.merge(id: south_park.id, parentId: movies.id)

      expect(south_park.reload.parent).to eq(movies)
    end

    it "moves a folder to the top level when parentId is sent empty" do
      get "/api/rest/updateFolder", params: auth_params.merge(id: south_park.id, parentId: "")

      expect(south_park.reload.parent).to be_nil
      expect(subsonic_response["folder"]).not_to have_key("parentId")
    end

    it "leaves the folder where it is when parentId isn't sent" do
      get "/api/rest/updateFolder", params: auth_params.merge(id: south_park.id, name: "South Park (Comedy Central)")

      expect(south_park.reload.parent).to eq(tv)
    end

    it "refuses to move a folder inside one of its own subfolders" do
      get "/api/rest/updateFolder", params: auth_params.merge(id: tv.id, parentId: south_park.id)

      expect(subsonic_error).to eq("code" => 0, "message" => "TV can't go inside itself or anything inside it")
      expect(tv.reload.parent).to be_nil
    end

    it "moves a deleted folder's videos and subfolders up into its parent" do
      season_one = create(:folder, user: user, parent: south_park, name: "Season 1")
      episode = create(:video, user: user, folder: south_park)

      get "/api/rest/deleteFolder", params: auth_params.merge(id: south_park.id)

      expect(subsonic_response["status"]).to eq("ok")
      expect(season_one.reload.parent).to eq(tv)
      expect(episode.reload.folder).to eq(tv)
    end

    it "refuses a delete that would put two folders of the same name side by side" do
      create(:folder, user: user, parent: tv, name: "Season 1")
      create(:folder, user: user, parent: south_park, name: "Season 1")

      get "/api/rest/deleteFolder", params: auth_params.merge(id: south_park.id)

      expect(subsonic_error).to eq("code" => 0, "message" => "Can't delete South Park: TV already has one named Season 1.")
      expect(Folder.exists?(south_park.id)).to be(true)
    end
  end
end
