## AngryShell
# `AngryShell` makes you less angry about running shell commands.
#
# AngryShell is extracted from YesMaster's CommonMob. Contains code adapted from Chef and open4.

require 'fcntl'
require 'stringio'
require 'pp'

module AngryShell
  class ShellError < StandardError
    attr_accessor :result

    def initialize(msg,result)
      @result = result
      super(msg)
    end
  end

  module ShellMethods
    def sh(*args,&blk)
      AngryShell::Shell.new(*args,&blk)
    end

    # call ruby, or a ruby command *without* the environment being cleaned of bundler spooge
    def bundler_sh(*args,&blk)
      args.options.without_cleaning_bundler = true
      AngryShell::Shell.new(*args,&blk)
    end
  end

  class Shell
    def debug(*msg)
      puts "sh: #{msg * ' '}"
    end

    attr_reader :options

    def initialize(*args,&block)
      @block = block
      @options = if Hash === args.last then args.pop else {} end

      case args.size
      when 0
        # no op
      when 1
        @options[:cmd] = args.first
      else
        @options[:cmd] = args
      end

      @options[:stream] = false unless @options.key?(:stream)
    end

    def execute
      error,out = nil,nil

      rv = popen4(options) {|pid,ipc|
        out   = ipc.stdout.read
        error = ipc.stderr.read
      }
      
      rv.stderr = error
      rv.stdout = out

      rv
    end

    # runs the command, raising if it doesn't return success.
    def run
      execute.ensure_ok!
    end

    # runs the command, returning true if it returns success.
    def ok?
      execute.ok?
    end

    # runs the command, returning its `stdout`. If the command doesn't return success, return a blank string.
    def to_s
      result = execute
      if result.ok?
        result.stdout.chomp
      else
        ''
      end
    end

    # We encapsulate the shell's result, including the Process::Status, stdout and stderr.
    class ShellResult < Struct.new(:process_result, :options, :stderr, :stdout)
      def ok?
        process_result.success?
      end

      def ensure_ok!
        unless ok?
          raise ShellError.new("unable to run command\ncommand=#{options[:cmd]}\noptions=#{options.pretty_inspect}\noutput=#{stdout}\nerror=#{stderr}",self)
        end
      end
    end

    class IPCState < Struct.new(:write,:read,:error,:exception)
      def initialize
        super(IO.pipe, IO.pipe, IO.pipe, IO.pipe)
      end

      def before_fork!
        exception.last.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
      end

      def child_after_fork!
        write.last.close
        STDIN.reopen write.first
        write.first.close

        self.write = STDIN

        read.first.close
        STDOUT.reopen read.last
        read.last.close

        self.read = STDOUT

        error.first.close
        STDERR.reopen error.last
        error.last.close

        self.error = STDERR

        exception.first.close
        self.exception = exception.last

        STDOUT.sync = STDERR.sync = true
      end

      def parent_after_fork!
        [write.first, read.last, error.last, exception.last].each {|fd| fd.close}

        self.write = write.last
        self.read  = read.first
        self.error = error.first
        self.exception = exception.first
      end

      alias :stdout :read
      alias :stderr :error
        
      def close_all
        [ read, write, error, exception ].flatten.compact.each {|fd| fd.close unless fd.closed?}
      end
        
    end

    # This is taken from Chef and rewritten.
    #
    # Chef's preamble:
    # This is taken directly from Ara T Howard's Open4 library, and then 
    # modified to suit the needs of Chef.  Any bugs here are most likely
    # my own, and not Ara's.
    #
    # The original appears in external/open4.rb in its unmodified form. 
    #
    # Thanks Ara!
    def popen4(args={}, &blk)
      popen4_normalise_args(args)
     
      
      # We pass and manipulate all IPC pipes around inside this object.
      ipc = IPCState.new

      verbose = $VERBOSE
      cid = begin
        $VERBOSE = nil
        ipc.before_fork!

        fork {
          popen4_proceed_as_child(args,ipc)
        }
      ensure
        $VERBOSE = verbose
      end

      popen4_proceed_as_parent(cid,args,ipc,&blk)
    end


    def popen4_proceed_as_parent(cid,args,ipc,&blk)
      ipc.parent_after_fork!

      # The first thing a parent does after forking is look for an Marshalled exception on the exception pipe.
      begin
        e = Marshal.load ipc.exception
        raise(Exception === e ? e : "unknown failure!")
      rescue EOFError # If we get an EOF error, then the exec was successful
        42
      ensure
        ipc.exception.close
      end

      ipc.write.sync = true

      if block_given?
        begin
          if args[:stream]
            # hand the block the pipes inside ipc to manipulate manually
            yield(cid, ipc)
            ShellResult.new(Process.waitpid2(cid).last, args)
          else
            popen4_parent_exhaust_io(cid,args,ipc,&blk)
          end
        ensure
          ipc.close_all
        end
      else
        # Return the pipes. The User needs to clean up after themselves.
        [cid, ipc]
      end
    end      

    # Use select to read the entire contents of the pipes into StringIOs.
    # This is the main change to come from Chef vs the original open4.
    def popen4_parent_exhaust_io(cid,args,ipc,&blk)
      output = StringIO.new
      error  = StringIO.new

      if args[:input]
        ipc.write.puts args[:input]
      end

      ipc.write.close

      stdout = ipc.read
      stderr = ipc.error

      stdout.sync = true
      stderr.sync = true

      stdout.fcntl(Fcntl::F_SETFL, stdout.fcntl(Fcntl::F_GETFL) | Fcntl::O_NONBLOCK)
      stderr.fcntl(Fcntl::F_SETFL, stderr.fcntl(Fcntl::F_GETFL) | Fcntl::O_NONBLOCK)

      stdout_finished = false
      stderr_finished = false

      results = nil

      while !stdout_finished && !stderr_finished
        begin
          channels_to_watch = []
          channels_to_watch << stdout if !stdout_finished
          channels_to_watch << stderr if !stderr_finished

          ready = IO.select(channels_to_watch, nil, nil, 1.0)
        rescue Errno::EAGAIN
          results = Process.waitpid2(cid, Process::WNOHANG)

          if results
            stdout_finished = true
            stderr_finished = true 
          end
        end

        if ready && ready.first.include?(stdout)
          line = results ? stdout.gets(nil) : stdout.gets
          if line
            output.write(line)
          else
            stdout_finished = true
          end
        end

        if ready && ready.first.include?(stderr)
          line = results ? stderr.gets(nil) : stderr.gets
          if line
            error.write(line)
          else
            stderr_finished = true
          end
        end
      end

      results = Process.waitpid2(cid) unless results

      output.rewind
      error.rewind

      ipc.read = output
      ipc.error = error

      blk[cid, ipc]

      ShellResult.new(results.last, args)
    end


    def popen4_proceed_as_child(args,ipc)
      ipc.child_after_fork!

      if args[:group]
        Process.egid = args[:group]
        Process.gid  = args[:group]
      end

      if args[:user]
        Process.euid = args[:user]
        Process.uid  = args[:user]
      end

      # Copy the specified environment across to the child's environment.
      # Keys with `nil` values are deleted from the environment.
      args[:environment].each do |key,value|
        if value.nil?
          ENV.delete(key.to_s)
        else
          ENV[key.to_s] = value
        end
      end

      if args[:umask]
        umask = ((args[:umask].respond_to?(:oct) ? args[:umask].oct : args[:umask].to_i) & 007777)
        File.umask(umask)
      end

      if args[:cwd]
        Dir.chdir args[:cwd]
      end

      begin
        cmd = args[:cmd]

        case cmd
        when Proc
          exit cmd.call.to_i
        when Array
          exec(*cmd)
        else
          exec(cmd)
        end

        raise 'forty-two' 
      rescue SystemExit
        exit $!.status
      rescue Object => e
        Marshal.dump(e, ipc.exception)
        ipc.exception.flush
      end

      ipc.exception.close unless (ipc.exception.closed?)
      exit!
    end      

    def popen4_normalise_args(args)
      # Do we wait for the child process to die before we yield
      # to the block, or after?
      #
      # By default, we are waiting before we yield the block.
      args[:stream] ||= false
      

      args[:user] ||= nil
      unless args[:user].kind_of?(Integer)
        args[:user] = Etc.getpwnam(args[:user]).uid if args[:user]
      end

      args[:group] ||= nil
      unless args[:group].kind_of?(Integer)
        args[:group] = Etc.getgrnam(args[:group]).gid if args[:group]
      end

      args[:environment] ||= {}

      # Default on C locale so parsing commands output can be done
      # independently of the node's default locale.
      # "LC_ALL" could be set to nil, in which case we also must ignore it.
      unless args[:environment].has_key?("LC_ALL")
        args[:environment]["LC_ALL"] = "C"
      end

      unless TrueClass === args[:without_cleaning_bundler]
        args[:environment].update('RUBYOPT' => nil, 'BUNDLE_GEMFILE' => nil, 'GEM_HOME' => nil, 'GEM_PATH' => nil)
      end

      # `:as` - run the command as another user, via sudo,
      if user = args[:as]
        if (evars = args[:environment].reject {|k,v| v.nil?}.map {|k,v| "#{k}=#{v}"}) && !evars.empty?
          env = "env #{evars.join(' ')}"
        else
          env = ''
        end
        
        args[:cmd] = "sudo -H -u #{user} #{env} #{args[:cmd]}"
      end
    end

    def massaged_args args
      args.dup.tap do |args_to_print|
        args_to_print[:environment] = e = args[:environment].dup

        %w{LC_ALL GEM_HOME GEM_PATH RUBYOPT BUNDLE_GEMFILE}.each {|env| e.delete(env)}

        args_to_print['cwd'] = args_to_print['cwd'].to_s if args_to_print['cwd']

        args_to_print.delete_if{|k,v| v.blank?}
      end
    end

  end
end

class String
  def sh(options={})
    AngryShell::Shell.new(self,options)
  end
end
