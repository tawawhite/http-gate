require "../gate"
require "opts"

class HttpGate
  include Opts

  CONFIG_FILE = "config.toml"

  USAGE = <<-EOF
    Usage: {{program}} [options]

    Options:
    {{options}}
    EOF

  option config_path : String?, "-c <config>", "config file", "config.toml"
  option verbose : Bool  , "-v", "Verbose output", false
  option version : Bool  , "--version", "Print the version and exit", false
  option help    : Bool  , "--help"   , "Output this help and exit" , false

  var logger : Logger = build_logger
  
  def run
    config = load_config
    if verbose
      config.verbose = true
      logger.level = Logger::DEBUG
    end

    front = Gate::Front.new
    front.logger = logger
    front.host   = config.front_host?
    front.port   = config.front_port?
    front.backs  = config.backs
    front.run
  end     

  private def load_config
    Gate::Config.parse_file(config_path)
  rescue Errno
    raise Gate::Abort.new("No such config file '#{config_path}'")
  end

  private def build_logger : Logger
    logger = Logger.new(STDOUT)
    logger.formatter = Logger::Formatter.new do |level, time, prog, mes, io|
      mark = level.to_s[0]
      # prog = prog.sub(/[a-z]+/, "") # "Back#1" => "B#1"
      time = time.to_s("%H:%M:%S")
      io << mark << " [" << time << "] " << prog << " " << mes
      # I [20:15:59] Front ...
    end
    return logger
  end

  def on_error(err)
    case err
    when Gate::Abort, TOML::Config::NotFound
      STDERR.puts "ERROR: #{err}".colorize(:red)
      exit 1
    else
      STDERR.puts Pretty.error(err).message.colorize(:red)
      logger.error "ERROR: #{err} (#{err.class.name})"
      logger.error(err.inspect_with_backtrace)
      exit 100
    end    
  end
end

HttpGate.run