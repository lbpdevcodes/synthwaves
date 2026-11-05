class API::V1::AuthController < ActionController::API
  rate_limit to: 10, within: 3.minutes, only: :native_token,
    by: -> { request.request_parameters[:email].to_s.presence || request.remote_ip },
    with: -> { render json: {error: "Too many attempts. Try again later."}, status: :too_many_requests }

  def create
    api_key = APIKey.find_by(client_id: params[:client_id])

    if api_key&.authenticate_secret_key(params[:secret_key])
      if api_key.expired?
        render json: {error: "API key has expired"}, status: :unauthorized
      else
        api_key.touch_last_used!(request.remote_ip)
        render_token(user_id: api_key.user_id, api_key_id: api_key.id)
      end
    else
      render_invalid_credentials
    end
  end

  # Reads the request body only: query strings end up in logs and stream URLs.
  def native_token
    body = request.request_parameters
    user = User.authenticate_by_subsonic_password(email: body[:email].to_s, password: body[:subsonic_password].to_s)

    user ? render_token(user_id: user.id) : render_invalid_credentials
  end

  private

  def render_token(claims)
    render json: {token: JWTService.encode(claims), expires_in: 3600}
  end

  def render_invalid_credentials
    render json: {error: "Invalid credentials"}, status: :unauthorized
  end
end
