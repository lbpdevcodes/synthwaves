# Answers a successful save. A form submitted from the layout's modal frame
# gets a page refresh: the page under the modal morphs to show the change, and
# the refreshed modal frame comes back empty. A form visited as a full page
# keeps the plain redirect.
#
# The refresh carries no request id. Turbo ignores a refresh whose id matches
# a request it sent itself, and by default turbo-rails stamps the id of the
# form submission that is being answered.
module ModalForm
  extend ActiveSupport::Concern

  private

  def respond_saved(location, notice:)
    if turbo_frame_request?
      flash[:notice] = notice
      render turbo_stream: turbo_stream.refresh(request_id: nil)
    else
      redirect_to location, notice: notice
    end
  end
end
