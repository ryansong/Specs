module Pod
  # Module which provides support for running executables.
  #
  # In a class it can be used as:
  #
  #     extend Executable
  #     executable :git
  #
  # This will create two methods `git` and `git!` both accept a command but
  # the later will raise on non successful executions. The methods return the
  # output of the command.
  #
  module Executable
    # Creates the methods for the executable with the given name.
    #
    # @param  [Symbol] name
    #         the name of the executable.
    #
    # @return [void]
    #
    def executable(name)
      define_method(name) do |*command|
        Executable.execute_command(name, Array(command).flatten, false)
      end

      define_method(name.to_s + '!') do |*command|
        Executable.execute_command(name, Array(command).flatten, true)
      end
    end

    # Executes the given command displaying it if in verbose mode.
    #
    # @param  [String] bin
    #         The binary to use.
    #
    # @param  [Array<#to_s>] command
    #         The command to send to the binary.
    #
    # @param  [Bool] raise_on_failure
    #         Whether it should raise if the command fails.
    #
    # @raise  If the executable could not be located.
    #
    # @raise  If the command fails and the `raise_on_failure` is set to true.
    #
    # @return [String] the output of the command (STDOUT and STDERR).
    #
    # @todo   Find a way to display the live output of the commands.
    #
    def self.execute_command(executable, command, raise_on_failure)
      bin = `which #{executable}`.strip
      raise Informative, "Unable to locate the executable `#{executable}`" if bin.empty?

      require 'shellwords'

      command = command.map(&:to_s)
      full_command = "#{bin} #{command.join(' ')}"

      if Config.instance.verbose?
        UI.message("$ #{full_command}")
        stdout, stderr = Indenter.new(STDOUT), Indenter.new(STDERR)
      else
        stdout, stderr = Indenter.new, Indenter.new
      end

      status = popen3(bin, command, stdout, stderr)
      output = stdout.join("\n") + stderr.join("\n")
      unless status.success?
        if raise_on_failure
          raise Informative, "#{full_command}\n\n#{output}"
        else
          UI.message("[!] Failed: #{full_command}".red)
        end
      end
      output
    end

    private

    def self.popen3(bin, command, stdout, stderr)
      require 'open3'
      Open3.popen3(bin, *command) do |i, o, e, t|
        read(o, stdout)
        read(e, stderr)

        i.close
        status = t.value

        o.flush
        e.flush
        sleep(0.1)

        status
      end
    end

    def self.read(input, output)
      Thread.new do
        buf = ''
        begin
          loop do
            s = input.readpartial(4096)
            buf << s
            lines = buf.split("\n")
            if buf[-1] == "\n"
              buf = ''
            else
              buf = lines[-1]
              lines.pop
            end
            lines.each { |l| output << (l << "\n") }
          end
        rescue EOFError
          output << (buf << "\n") unless buf.size == 0
        end
      end
    end

    #-------------------------------------------------------------------------#

    # Helper class that allows to write to an {IO} instance taking into account
    # the UI indentation level.
    #
    class Indenter < ::Array
      # @return [Fixnum] The indentation level of the UI.
      #
      attr_accessor :indent

      # @return [IO] the {IO} to which the output should be printed.
      #
      attr_accessor :io

      # Init a new Indenter
      #
      # @param [IO] io @see io
      #
      def initialize(io = nil)
        @io = io
        @indent = ' ' * UI.indentation_level
      end

      # Stores a portion of the output and prints it to the {IO} instance.
      #
      # @param  [String] value
      #         the output to print.
      #
      # @return [void]
      #
      def <<(value)
        super
      ensure
        @io << "#{ indent }#{ value }" if @io
      end
    end
  end
end
