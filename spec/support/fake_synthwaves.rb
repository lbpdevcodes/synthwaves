require "socket"
require "json"

# Plays synthwaves.fm and its storage for one run of the script: answers each
# request by path, files a video sent with its details ready, and refuses a
# subtitle file whose name mentions "notes".
class FakeSynthwaves
  attr_reader :requests

  def initialize
    @server = TCPServer.new("127.0.0.1", 0)
    @requests = []
    @thread = Thread.new { loop { serve(@server.accept) } }
  end

  def url = "http://127.0.0.1:#{@server.addr[1]}"

  def stop
    @thread.kill
    @server.close
  end

  private

  def serve(client)
    method, path = client.gets.split
    headers = read_headers(client)
    body = client.read(headers.fetch("content-length", "0").to_i)
    @requests << [method, path, body]
    status, json = reply(method, path, body)
    payload = JSON.generate(json)
    client.write("HTTP/1.1 #{status} OK\r\nContent-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
  ensure
    client.close
  end

  def read_headers(client)
    lines = []
    while (line = client.gets) && line != "\r\n"
      lines << line
    end
    lines.to_h { |line| line.split(": ", 2).then { |name, value| [name.downcase, value.strip] } }
  end

  def reply(method, path, body)
    case [method, path]
    in ["POST", "/api/v1/auth/token"] then [200, {token: "token"}]
    in ["POST", "/api/import/direct_uploads"] then [201, {signed_id: "blob", direct_upload: {url: "#{url}/storage", headers: {}}}]
    in ["PUT", "/storage"] then [200, {}]
    in ["POST", "/api/import/videos"] then [201, {id: 7, title: "Heat", status: JSON.parse(body).key?("details") ? "ready" : "processing"}]
    in ["POST", "/api/import/videos/7/subtitles"] then subtitle_reply(JSON.parse(body).fetch("filename"))
    end
  end

  def subtitle_reply(filename)
    return [422, {error: "#{filename}: no subtitle cues found"}] if filename.include?("notes")

    [201, {id: 1, label: File.basename(filename, ".*"), language: nil, kind: "subtitles"}]
  end
end
