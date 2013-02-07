require "pty"
require "tempfile"

module Utils
  def self.print_output(output, last=false)
    while (idx = output.index("\n")) do
      line = output.slice!(0, idx+1)
      message "       #{line}"
    end
    message "       #{output}" if last and output != ""
    output
  end

  def self.log(msg, &blk)
    if blk
      start = Time.now
      res = nil
      log("#{msg} at=start")
      begin
        res = yield
      rescue => e
        log("#{msg} at=error class='#{e.class}' message='#{e.message}' elapsed=#{Time.now - start}")
        raise(e)
      end
      log("#{msg} at=finish elapsed=#{Time.now - start}")
      res
    else
      IO.popen("logger -t #{ENV["LOG_TOKEN"]}[slugc.#{$$}] -p user.notice", "w") { |io| io.write("slugc #{msg}") } if ENV["LOG_TOKEN"]
      IO.popen("logger -t slugc[#{$$}] -p user.notice", "w") { |io| io.write("slugc #{msg}") }
    end
  end

  def self.log_error(msg)
    IO.popen("logger -t #{ENV["LOG_TOKEN"]}[slugc.#{$$}] -p user.error", "w") { |io| io.write("slugc #{msg}") } if ENV["LOG_TOKEN"]
    IO.popen("logger -t slugc[#{$$}] -p user.error", "w") { |io| io.write("slugc #{msg}") }
  end

  def self.userlog(heroku_log_token, msg)
    IO.popen("logger -t #{heroku_log_token}[slugc] -p user.notice", "w") { |io| io.write(msg) }
  end
end
