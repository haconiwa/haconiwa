def __main__(argv)
  if argv[1] == "version"
    puts "haconiwa: v#{Haconiwa::VERSION}"
  else
    argv.shift
    Haconiwa::Cli.run(argv)
  end
end
