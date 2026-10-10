# Answers a successful save from a form that may sit in the layout's modal
# frame. An update refreshes the page under the modal (see InPlaceRefresh),
# and the refreshed modal frame comes back empty. A create visits the new
# record's page. A form visited as a full page keeps the plain redirect.
module ModalForm
  extend ActiveSupport::Concern
  include InPlaceRefresh

  private

  def respond_saved(location, notice:)
    if turbo_frame_request?
      refresh_with_notice(notice)
    else
      redirect_to location, notice: notice
    end
  end

  def respond_created(location, notice:)
    if turbo_frame_request?
      flash[:notice] = notice
      render turbo_stream: helpers.turbo_stream_action_tag(:visit, location: polymorphic_path(location))
    else
      redirect_to location, notice: notice
    end
  end
end
