# Remote MCP endpoint for LLM agents (POST /mcp). Speaks JSON-RPC 2.0,
# not the REST envelope, so it stands alone from API::V1::BaseController
# while reusing APIKey credentials via HTTP Basic (client_id:secret_key).
# Stateless: a fresh MCP::Server is built per request, so key revocation
# takes effect on the next call. The body is never read through params —
# malformed JSON must reach the gem's -32700 handling.
class AgentGatewayController < ActionController::API
  rate_limit to: 60, within: 1.minute,
    by: -> {
      ActionController::HttpAuthentication::Basic.user_name_and_password(request)&.first.presence ||
        request.remote_ip
    },
    with: -> { render_json_rpc_error(-32_000, "Too many requests", status: :too_many_requests) }

  before_action :authenticate_api_key!, only: :create

  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_json_rpc_error(-32_700, "Parse error")
  end

  def create
    json = AgentGateway::Server.for(current_api_key).handle_json(request.body.read)
    json ? render(json: json) : head(:accepted)
  end

  def method_not_allowed
    response.set_header("Allow", "POST")
    head :method_not_allowed
  end

  private

  attr_reader :current_api_key

  def authenticate_api_key!
    client_id, secret_key = ActionController::HttpAuthentication::Basic.user_name_and_password(request)
    api_key = client_id.present? ? APIKey.active.find_by(client_id: client_id) : nil

    if api_key&.authenticate_secret_key(secret_key.to_s)
      api_key.touch_last_used!(request.remote_ip)
      @current_api_key = api_key
    else
      response.set_header("WWW-Authenticate", 'Basic realm="Synthwaves MCP"')
      render_json_rpc_error(-32_001, "Invalid or missing API key", status: :unauthorized)
    end
  end

  def render_json_rpc_error(code, message, status: :ok)
    render json: {jsonrpc: "2.0", id: nil, error: {code: code, message: message}}, status: status
  end
end
