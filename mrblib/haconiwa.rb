def __main__(argv)
  if ENV['HACONIWA_RUN_AS_CRIU_ACTION_SCRIPT'] == "true"
    ret = Haconiwa.run_as_criu_action_script
    exit ret
  end

  argv.shift
  case argv[0]
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
    Haconiwa::Cli.checkpoint(argv)
  when "restore"
    Haconiwa::Cli.restore(argv)
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
    checkpoint - create container's checkpoint image following config, using syscall hook
    restore    - restore a container from checkpint
    reload     - reload running container parameters, following its current config
    kill       - kill the running container
    version    - show version
    revisions  - show mgem/mruby revisions which haconiwa bin uses

Invoke `haconiwa COMMAND -h' for details.
    USAGE
  end
end
