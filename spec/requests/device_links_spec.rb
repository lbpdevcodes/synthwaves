require "rails_helper"

RSpec.describe "Device links", type: :request do
  let(:user) { create(:user, subsonic_password: "tv-subsonic-pw") }
  let!(:sign_in) { DeviceSignIn.start(device_name: "Apple TV") }

  def tv_check_in
    post "/api/v1/device_sign_in_claim", params: {secret: sign_in.secret}, as: :json
  end

  describe "GET /link" do
    it "brings someone signed out back to the code after they sign in" do
      get "/link", params: {code: sign_in.display_code}
      expect(response).to redirect_to(new_session_path)

      login_user(user)

      expect(response).to redirect_to("http://www.example.com/link?code=#{sign_in.display_code}")
    end

    it "fills in the code from the link and says what the device calls itself" do
      login_user(user)

      get "/link", params: {code: sign_in.display_code}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(value="#{sign_in.display_code}"))
      expect(response.body).to include("The device showing this code calls itself “Apple TV”.")
    end

    it "keeps the name a device gives itself off the button, so it can't word the confirmation" do
      lure = DeviceSignIn.start(device_name: "to synthwaves.fm")
      login_user(user)

      get "/link", params: {code: lure.display_code}

      expect(response.body).to include(%(value="Sign In TV"))
      expect(response.body).not_to include(%(value="Sign In to synthwaves.fm"))
      expect(response.body).to include("Only continue if this code is on your own TV, in front of you.")
    end
  end

  describe "POST /link" do
    before { login_user(user) }

    it "signs the TV in to the account of whoever entered its code" do
      post "/link", params: {code: sign_in.display_code}

      expect(response).to redirect_to(link_path)
      expect(flash[:notice]).to eq("Apple TV is signing in. It'll be ready in a few seconds.")
      tv_check_in
      expect(response.parsed_body).to eq("email" => user.email_address, "subsonic_password" => "tv-subsonic-pw")
    end

    it "takes the code in lowercase, with spaces and without the dash" do
      post "/link", params: {code: " #{sign_in.code.downcase.insert(4, " ")} "}

      expect(response).to redirect_to(link_path)
    end

    it "refuses a code that has expired" do
      travel DeviceSignIn::LIFETIME + 1.second

      post "/link", params: {code: sign_in.display_code}

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "won't move a TV someone else already signed in to their account" do
      sign_in.approve(create(:user))

      post "/link", params: {code: sign_in.display_code}

      expect(response).to have_http_status(:unprocessable_content)
      tv_check_in
      expect(response.parsed_body["email"]).not_to eq(user.email_address)
    end

    it "stops taking codes from one account after 10 tries in 10 minutes" do
      10.times { post "/link", params: {code: "BBBB-CCCC"} }

      post "/link", params: {code: sign_in.display_code}

      expect(response).to redirect_to(link_path)
      expect(flash[:alert]).to eq("Too many tries. Wait a few minutes and try again.")
      tv_check_in
      expect(response).to have_http_status(:accepted)
    end

    it "says so when no TV is showing the code" do
      post "/link", params: {code: "BBBB-CCCC"}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("That code didn&#39;t work. Check the code on your TV, or get a new one there.")
    end
  end
end
