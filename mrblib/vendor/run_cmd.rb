class RunCmd
  def initialize(tag)
    @tag = tag
  end

  def run(cmd)
    r, sout = IO.pipe
    pid = Process.fork do
      p = Procutil.system4 cmd, nil, sout, sout
      sout.close
      exit p.exitstatus
    end
    sout.close

    while(l = r.readline rescue false)
      puts "[#{@tag}]:\t#{l.chomp.cyan}"
    end
    waitcommand(pid, cmd)
  end

  def run_with_input(cmd, input_data)
    r, sout = IO.pipe
    sin, w = IO.pipe
    w.write input_data
    w.close

    pid = Process.fork do
      p = Procutil.system4 cmd, sin, sout, sout
      sout.close
      exit p.exitstatus
    end
    sout.close

    while(l = r.readline rescue false)
      puts "[#{@tag}]:\t#{l.chomp.cyan}"
    end
    waitcommand(pid, cmd)
  end

  private
  def waitcommand(pid, cmd)
    pid, status = *Process.waitpid2(pid)
    if status.success?
      $stderr.puts "Command success: #{cmd} exited #{status.exitstatus}"
    else
      raise "Command failed...: #{cmd} exited #{status.exitstatus}"
    end

    return [pid, status]
  end
end
