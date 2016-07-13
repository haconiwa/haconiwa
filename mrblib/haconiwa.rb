def __main__(argv)
  argv.shift
  case argv[0]
  when "version"
    puts "haconiwa: v#{Haconiwa::VERSION}"
  when "revisions"
    Haconiwa::Cli.revisions
  when "run"
    Haconiwa::Cli.run(argv)
  when "attach"
    Haconiwa::Cli.attach(argv)
  else
    puts <<-USAGE
haconiwa - The MRuby on Container
commands:
    run       - run the container
    attach    - attach to existing container
    version   - show version
    revisions - show mgem/mruby revisions which haconiwa bin uses
    USAGE
  end
end
