require "pty"
require "tempfile"

module Utils
  def self.message(text)
    $stderr.print(text)
    $stderr.flush
  end

  class BashFailed < StandardError; end

  # Like Kernel#system, but with better logging and the ability to return out
  def self.system(command, stream_out=false)
    log("utils system command='#{command}'")
    IO.popen("#{command} 2>&1", "r") do |io|
      start = Time.now
      io.sync = true
      out = ""
      begin
        loop do
          if IO.select([io], [], [], 600)
            if stream_out
              message(io.readpartial(80))
            else
              out += io.readpartial(80)
              out = print_output(out)
            end
          end
        end
      rescue Timeout::Error => e
        log_error("command='#{command}' exit_status=#{$?.exitstatus} out='#{out}' at=timeout elapsed=#{Time.now.to_f - start}")
        raise(e)
      rescue EOFError
        print_output(out, true) unless stream_out
      end
    end
    if $?.exitstatus != 0
      out.each_line do |line|
        log("utils bash command='#{log_command}' out=\"#{line.gsub('"', "'")}\"")
      end
      raise(BashFailed, "command='#{log_command}' exit_status=#{$?.exitstatus} out='#{out}'")
    end
    out
  end

  def self.print_output(output, last=false)
    while (idx = output.index("\n")) do
      line = output.slice!(0, idx+1)
      message "       #{line}"
    end
    message "       #{output}" if last and output != ""
    output
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
