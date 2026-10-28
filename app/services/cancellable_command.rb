# Runs a command, stopping it once `cancelled` returns true.
# Returns :succeeded, :failed or :cancelled.
class CancellableCommand
  def self.run(*command, cancelled:, poll_interval: 5)
    new(command, cancelled:, poll_interval:).run
  end

  def initialize(command, cancelled:, poll_interval:)
    @command = command
    @cancelled = cancelled
    @poll_interval = poll_interval
  end

  def run
    pid = Process.spawn(*@command, out: File::NULL, err: File::NULL)
    until (status = exit_status(pid))
      return stop(pid) if @cancelled.call
      sleep @poll_interval
    end
    status.success? ? :succeeded : :failed
  end

  private

  def exit_status(pid)
    Process.wait2(pid, Process::WNOHANG)&.last
  end

  def stop(pid)
    Process.kill("TERM", pid)
    Process.wait(pid)
    :cancelled
  end
end
