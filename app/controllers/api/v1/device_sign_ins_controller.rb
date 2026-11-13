# Starts a code sign-in for a TV. Nobody is signed in yet, so it takes no token.
class API::V1::DeviceSignInsController < ActionController::API
  before_action :no_store
  rate_limit to: 10, within: 10.minutes,
    with: -> { render json: {error: "Too many attempts. Try again later."}, status: :too_many_requests }

  def create
    sign_in = DeviceSignIn.start(device_name: request.request_parameters[:device_name].to_s)

    render status: :created, json: {
      code: sign_in.display_code,
      secret: sign_in.secret,
      url: link_url,
      url_with_code: link_url(code: sign_in.display_code),
      expires_in: DeviceSignIn::LIFETIME.to_i,
      interval: DeviceSignIn::CHECK_IN_INTERVAL.to_i
    }
  end
end
