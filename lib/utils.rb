require "pty"
require "tempfile"

module Utils
  def self.message(text)
    $stderr.print(text)
    $stderr.flush
  end

  class BashFailed < StandardError; end
  class TimeoutError < StandardError; end

  def self.bash(command, timeout_secs=600)
    log_command = command.gsub(/\:\/\/[^\@]+\@/, "://xxx@")
    log("utils bash command='#{log_command}', timeout_secs=#{timeout_secs}")
    out = ""
    IO.popen("#{command} 2>&1", "r") do |io|
      begin
        loop do
          start = Time.now.to_f
          if IO.select([io], [], [], timeout_secs)
            out += io.readpartial(80)
          end

          timeout_secs -= Time.now.to_f - start
          if timeout_secs < 0
            Process.kill("KILL", io.pid) # FIXME: Kill children?
            raise(TimeoutError, "command='#{log_command}' exit_status=#{$?.exitstatus} out='#{out}' at=timeout elapsed=#{Time.now.to_f - start}")
          end
        end
      rescue EOFError
      end
    end

    if $?.exitstatus == 0
      out
    else
      out.each_line do |line|
        log("utils bash command='#{log_command}' out=\"#{line.gsub('"', "'")}\"")
      end
      raise(BashFailed, "command='#{log_command}' exit_status=#{$?.exitstatus} out='#{out}'")
    end
  end

  def self.spawn(command, prefix=true, timeout_secs=600)
    log("utils spawn command='#{command}' timeout_secs='#{timeout_secs}'")
    IO.popen("#{command} 2>&1", "r") do |io|
      io.sync = true
      start = Time.now.to_f
      out = ""
      begin
        loop do
          select_start = Time.now.to_f
          if IO.select([io], [], [], timeout_secs)
            if prefix
              out += io.readpartial(80)
              out = print_output(out)
            else
              message(io.readpartial(80))
            end
          end

          timeout_secs -= Time.now.to_f - select_start
          if timeout_secs < 0
            Process.kill("KILL", io.pid) # FIXME: Kill children?
            raise(TimeoutError, "command='#{command}' exit_status=#{$?.exitstatus} out='#{out}' at=timeout elapsed=#{Time.now.to_f - start}")
          end
        end
      rescue EOFError
        prefix ? print_output(out, true) : message(out)
      end
    end
    $?.exitstatus
  end

  def self.print_output(output, last=false)
    while (idx = output.index("\n")) do
      line = output.slice!(0, idx+1)
      message "       #{line}"
    end
    message "       #{output}" if last and output != ""
    output
  end

  def self.timeout(secs)
    begin
      require "system_timer"
      SystemTimer.timeout(secs) { yield }
    rescue LoadError
      require "timeout"
      Timeout.timeout(secs) { yield }
    end
  end

  def self.clear_var(k)
    v = ENV.delete(k)
    begin
      yield
    ensure
      ENV[k] = v
    end
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
