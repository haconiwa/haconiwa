def __main__(argv)
  argv.shift

  if ENV['HACONIWA_RUN_AS_CRIU_ACTION_SCRIPT'] == "true" && !argv[0]
    ret = Haconiwa.run_as_criu_action_script
    exit ret
  end

  Haconiwa.current_subcommand = argv[0]

  case Haconiwa.current_subcommand
  when "_restored" # only invoked via criu
    Haconiwa::Cli._restored(argv)
  when "version"
    puts "haconiwa: v#{Haconiwa::VERSION}"
  when "revisions"
    Haconiwa::Cli.revisions
  when "new", "init"
    Haconiwa::Cli.init(argv)
  when "create"
    Haconiwa::Cli.create(argv)
  when "provision"
    Haconiwa::Cli.provision(argv)
  when "archive"
    Haconiwa::Cli.archive(argv)
  when "start", "run"
    Haconiwa::Cli.run(argv)
  when "attach"
    Haconiwa::Cli.attach(argv)
  when "checkpoint"
    raise NotImplementedError, "0.9.x cannot use checkpoint"
    # Haconiwa::Cli.checkpoint(argv)
  when "restore"
    raise NotImplementedError, "0.9.x cannot use restore"
    # Haconiwa::Cli.restore(argv)
  when "reload"
    Haconiwa::Cli.reload(argv)
  when "kill"
    Haconiwa::Cli.kill(argv)
  else
    puts <<-USAGE
haconiwa - The MRuby on Container
commands:
    new        - generate haconiwa's config DSL file template
    create     - create the container rootfs
    provision  - provision already booted container rootfs
    archive    - create, provision, then archive rootfs to image
    start      - run the container
    attach     - attach to existing container
    checkpoint - create container's checkpoint image following config, using syscall hook # no impl
    restore    - restore a container from checkpint # no impl
    reload     - reload running container parameters, following its current config
    kill       - kill the running container
    version    - show version
    revisions  - show mgem/mruby revisions which haconiwa bin uses

Invoke `haconiwa COMMAND -h' for details.
    USAGE
  end
end
