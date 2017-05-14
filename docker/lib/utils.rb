require 'systemu'
require 'logger'
require 'ohai'
require 'ruby_expect'

# Execute a shell command, with optional environment. stdout and stderr
# will be sent to the logger if the command exits with non-zero status.
def shlog(cmd, env={}, dir=nil)
#  logger.info("Executing: [#{cmd.gsub(/\s{2,}/, ' ')}]")
  logger.info("Executing: [#{cmd.gsub(/--password \w+/, '--password ******')}]")
  output   = ''
  stderror = ''
  status = systemu("#{cmd}", :stdout => output, :stderr => stderror, :env => env, :cwd => dir)
  
  if status.exitstatus > 0
    logger << output
    logger.error stderror
    #fail "Command failed with status (#{status.exitstatus}): [#{cmd.gsub(/\s{2,}/, ' ')}]."
    fail "Command failed with status (#{status.exitstatus}): [#{cmd.gsub(/--password \w+/, '--password ******')}]."
  end
  output if !output.empty?
end

# direct logger to stdout
def logger
  logger = Logger.new(STDOUT)
end

def ohai
  ohai = nil
  if ohai.nil?
    ohai ||= ::Ohai::System.new
    ohai.load_plugins
    ohai.require_plugin('os')
    ohai.require_plugin('platform')
  end
  ohai
end

def fpmCmd
  fpm_cmd = [ 'fpm -s dir -t rpm', "--architecture #{@arch}", "--name #{@name}" ]

  @fpmparams.keys.each do |arg|
    case arg.to_s
    when 'rpm_output_dir'
      fpm_cmd.push("--package #{@fpmparams[:rpm_output_dir]}#{@pkgname}")
    when 'depends', 'config-files'
      @fpmparams[arg].each { |argp| fpm_cmd.push("--#{arg} \'#{argp}\'") }
    when 'after-install', 'pre-install', 'after-remove', 'before-remove'
      fpm_cmd.push("--#{arg} #{pwd}/#{@name}/input/scripts/#{@fpmparams[arg]}")
    else
      fpm_cmd.push("--#{arg} #{@fpmparams[arg]}")
    end
  end
  fpm_cmd.push([ "-C #{@tmpdir}/contents", "." ])
end

def runFpm
  logger.info "Executing #{fpmCmd.join(' ').inspect}"
  begin
    exp = RubyExpect::Expect.spawn(fpmCmd.join(' '), :debug => true)
    exp.procedure do
      retval = 0
      while(retval != 2)
        retval = any do
          expect(/File already exists, refusing to continue/) do
            Logger.new(STDOUT).error last_match.to_s.chomp
          end
          expect "Enter pass phrase:" do
            send "@{params[:gpg_passphrase]}"
          end
          expect(/Created package.*/) do
            Logger.new(STDOUT).info last_match.to_s.chomp
          end
        end
      end
    end
  rescue RubyExpect::ClosedError => boom
    logger.error boom
    raise RuntimeError
  end
end
