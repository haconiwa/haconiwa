def __main__(argv)
  argv.shift
  case argv.shift
  when "version"
    puts "haconiwa: v#{Haconiwa::VERSION}"
  when "run"
    Haconiwa::Cli.run(argv)
  else
    puts <<-USAGE
haconiwa - The MRuby on Container
commands:
    run     - run the container
    version - show version
    USAGE
  end
end
