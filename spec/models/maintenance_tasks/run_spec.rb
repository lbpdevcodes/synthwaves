require "rails_helper"

# Guards the schema of maintenance_tasks_runs, not the gem. The gem never
# assigns tick_count on create -- it only calls update_counters -- so the
# column default is the only thing that keeps the value non-nil. A gem
# migration widened the column to bigint without repeating its options, and
# SQLite rebuilt the table without the default, which 500s the whole UI.
RSpec.describe MaintenanceTasks::Run do
  # The state the bug needs: a total is known, no batch has completed yet.
  def enqueued_run
    described_class.create!(
      task_name: "Maintenance::RetagChannelArtistTracksTask",
      tick_total: 196
    )
  end

  it "starts a run with a tick count of zero rather than nil" do
    expect(enqueued_run.tick_count).to eq(0)
  end

  it "reports progress for a run that knows its total but has not ticked" do
    progress = MaintenanceTasks::Progress.new(enqueued_run)

    expect(progress.value).to eq(0)
  end

  it "estimates time to completion for a run that has not ticked" do
    expect { enqueued_run.time_to_completion }.not_to raise_error
  end
end
