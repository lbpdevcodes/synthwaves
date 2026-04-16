class API::Subsonic::RadioController < API::Subsonic::BaseController
  def get_internet_radio_stations
    stations = []

    current_user.external_streams.where(source_type: "stream").each do |stream|
      stations << {
        id: "stream-#{stream.id}",
        name: stream.name,
        streamUrl: stream.stream_url,
        homePageUrl: stream.original_url || ""
      }
    end

    render_subsonic(
      internetRadioStations: {
        internetRadioStation: stations
      }
    )
  end
end
