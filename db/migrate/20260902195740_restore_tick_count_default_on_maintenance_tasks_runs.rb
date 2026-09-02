# The gem's install migration created tick_count as `default: 0, null: false`.
# ChangeRunsTickColumnsToBigints then re-declared it as bigint and passed no
# options, and the column has carried neither the default nor NOT NULL since.
#
# The pinned Rails preserves both across that same change -- verified against
# 8.2.0.alpha -- so the loss dates to the Rails in use when that migration ran
# on 2026-03-08. It does not reproduce on a fresh migrate, which is why the
# column needs repairing here rather than by re-running the gem's migration.
#
# The gem never assigns tick_count on create; it only calls update_counters and
# relies on the column default. So every run has started NULL, and
# Progress#over_total? raised on `nil > tick_total` once a run had a total but
# no tick yet, returning 500 for the whole maintenance UI.
class RestoreTickCountDefaultOnMaintenanceTasksRuns < ActiveRecord::Migration[8.2]
  def up
    # Must precede the NOT NULL constraint, or existing rows reject it.
    execute("UPDATE maintenance_tasks_runs SET tick_count = 0 WHERE tick_count IS NULL")

    change_column(:maintenance_tasks_runs, :tick_count, :bigint, default: 0, null: false)
  end

  def down
    change_column(:maintenance_tasks_runs, :tick_count, :bigint, default: nil, null: true)
  end
end
