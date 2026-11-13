require "rails_helper"

RSpec.describe DeviceSignIn, type: :model do
  it "calls a device that gives no name a TV" do
    expect(DeviceSignIn.start(device_name: " ").device_name).to eq("TV")
  end

  it "keeps a device's name short enough for a button" do
    expect(DeviceSignIn.start(device_name: "A" * 500).device_name.length).to eq(40)
  end

  it "clears away expired codes when a TV asks for a new one" do
    expired = DeviceSignIn.start(device_name: "Apple TV")
    travel DeviceSignIn::LIFETIME + 1.second

    DeviceSignIn.start(device_name: "Apple TV")

    expect(DeviceSignIn.exists?(expired.id)).to be(false)
  end

  it "doesn't stop the account that entered its code from being deleted" do
    user = create(:user)
    sign_in = DeviceSignIn.start(device_name: "Apple TV")
    sign_in.approve(user)

    user.destroy!

    expect(DeviceSignIn.exists?(sign_in.id)).to be(false)
  end
end
