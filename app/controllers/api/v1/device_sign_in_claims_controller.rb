# Where a TV checks in with the secret its code sign-in gave it.
class API::V1::DeviceSignInClaimsController < ActionController::API
  before_action :no_store
  rate_limit to: 30, within: 1.minute,
    with: -> { render json: {error: "Too many attempts. Try again later."}, status: :too_many_requests }

  def create
    sign_in = DeviceSignIn.find_by_secret(request.request_parameters[:secret].to_s)

    if sign_in.nil?
      render_expired
    elsif sign_in.pending?
      render status: :accepted, json: {status: "pending"}
    elsif (user = sign_in.claim)
      render json: {email: user.email_address, subsonic_password: user.subsonic_password}
    else
      render_expired
    end
  end

  private

  def render_expired
    render status: :not_found, json: {error: "This code has expired. Get a new one on the TV."}
  end
end
