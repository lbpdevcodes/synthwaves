# The page at /link where someone signed in enters the code a TV shows, which
# signs that TV in to their account.
class DeviceLinksController < ApplicationController
  rate_limit to: 10, within: 10.minutes, only: :create, by: -> { Current.user.id },
    with: -> { redirect_to link_path, alert: "Too many tries. Wait a few minutes and try again." }

  def show
    @device_name = DeviceSignIn.find_pending(params[:code])&.device_name
  end

  def create
    sign_in = DeviceSignIn.find_pending(params[:code])

    if sign_in&.approve(Current.user)
      redirect_to link_path, notice: "#{sign_in.device_name} is signing in. It'll be ready in a few seconds."
    else
      flash.now[:alert] = "That code didn't work. Check the code on your TV, or get a new one there."
      render :show, status: :unprocessable_content
    end
  end
end
