# Folds one record into another. The record in the path survives and the source
# is destroyed. Both are looked up through the current user's library, so a
# foreign ID on either side is a 404. Subclasses name the parts that differ.
class API::V1::MergesController < API::V1::BaseController
  def create
    survivor = records.find(survivor_id)
    merger.call(target: survivor, source: records.find(source_id))

    render json: serializer.render_as_hash(survivor.reload, view: :full)
  rescue ActiveRecord::RecordNotFound
    render_not_found
  rescue merger::Error => e
    render_error(e.message)
  end
end
