# Copyright, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'fiber'
require 'process/terminal'

module Process
	# A group of tasks which can be run asynchrnously using fibers. Someone must call Group#wait to ensure that all fibers eventually resume.
	class Group
		def self.wait(**options, &block)
			group = Group.new(**options)
			
			group.wait(&block)
		end
		
		class Command
			def initialize(foreground: false, **options)
				@options = options
				@foreground = foreground
				
				@fiber = Fiber.current
				@pid = nil
			end
			
			attr :options
			
			attr :pid
			
			def foreground?
				@foreground
			end
			
			def resume(*arguments)
				@fiber.resume(*arguments)
			end
			
			def kill(signal = :INT)
				Process.kill(signal, @pid)
			end
		end
		
		# Executes a command using Process.spawn with the given arguments and options.
		class Spawn < Command
			def initialize(arguments, **options)
				@arguments = arguments
				
				super(**options)
			end
			
			attr :arguments
			
			def call(**options)
				options = @options.merge(options)
				
				@pid = Process.spawn(*@arguments, **options)
			end
		end
		
		# Runs a given block using a forked process.
		class Fork < Command
			def initialize(block, **options)
				@block = block
				
				super(**options)
			end
			
			def call(**options)
				options = @options.merge(options)
				
				@pid = Process.fork(&@block)
				
				if options[:pgroup] == true
					# Establishes the child process as a process group leader:
					Process.setpgid(@pid, 0)
				elsif pgroup = options[:pgroup]
					# Set this process as part of the existing process group:
					Process.setpgid(@pid, pgroup)
				end
				
				return @pid
			end
			
			def resume(*arguments)
				@fiber.resume(*arguments)
			end
		end
		
		# Create a new process group. Can specify `limit:` which limits the maximum number of concurrent processes.
		def initialize(limit: nil, terminal: Terminal::Device.new?)
			raise ArgumentError.new("Limit must be nil (unlimited) or > 0") unless limit == nil or limit > 0
			
			@pid = Process.pid
			
			@terminal = terminal
			
			@queue = []
			@limit = limit
			
			@running = {}
			@fiber = nil
			
			@pgid = nil
			
			# Whether we can actively schedule tasks or not:
			@waiting = false
		end
		
		# A table of currently running processes.
		attr :running
		
		# The maximum number of processes to run concurrently, or zero 
		attr_accessor :limit
		
		# The id of the process group, only valid if processes are currently running.
		def id
			raise RuntimeError.new("No processes in group, no group id available.") if @running.size == 0
			
			-@pgid
		end
		
		def queued?
			@queue.size > 0
		end
		
		# Are there processes currently running?
		def running?
			@running.size > 0
		end
		
		# Run a process in a new fiber, arguments have same meaning as Process#spawn.
		def run(*arguments, **options)
			Fiber.new do
				exit_status = self.spawn(*arguments, **options)
				
				yield exit_status if block_given?
			end.resume
		end
		
		def async
			Fiber.new do
				yield self
			end.resume
		end
		
		# Run a specific command as a child process.
		def spawn(*arguments, **options)
			append! Spawn.new(arguments, **options)
		end
		
		# Fork a block as a child process.
		def fork(**options, &block)
			append! Fork.new(block, **options)
		end
		
		# Whether or not #spawn, #fork or #run can be scheduled immediately.
		def available?
			if @limit
				@running.size < @limit
			else
				true
			end
		end
		
		# Whether or not calling #spawn, #fork or #run would block the caller fiber (i.e. call Fiber.yield).
		def blocking?
			not available?
		end
		
		# Wait for all running and queued processes to finish. If you provide a block, it will be invoked before waiting, but within canonical signal handling machinery.
		def wait
			raise ArgumentError.new("Cannot call Process::Group#wait from child process!") unless @pid == Process.pid
			
			waiting do
				yield(self) if block_given?
				
				while running?
					process, status = wait_one
					
					schedule!
					
					process.resume(status)
				end
			end
			
			# No processes, process group is no longer valid:
			@pgid = nil
			
			return self
		rescue Interrupt
			# If the user interrupts the wait, interrupt the process group and wait for them to finish:
			self.kill(:INT)
			
			# If user presses Ctrl-C again (or something else goes wrong), we will come out and kill(:TERM) in the ensure below:
			wait_all
			
			raise
		ensure
			# You'd only get here with running processes if some unexpected error was thrown in user code:
			begin
				self.kill(:TERM)
			rescue Errno::EPERM
				# Sometimes, `kill` code can give EPERM, if any signal couldn't be delivered to a child. This might occur if an exception is thrown in the user code (e.g. within the fiber), and there are other zombie processes which haven't been reaped yet. These should be dealt with below, so it shouldn't be an issue to ignore this condition.
			end
			
			# Clean up zombie processes - if user presses Ctrl-C or for some reason something else blows up, exception would propagate back to caller:
			wait_all
		end
		
		# Send a signal to all currently running processes. No-op unless #running?
		def kill(signal = :INT)
			if running?
				Process.kill(signal, id)
			end
		end
		
		def to_s
			"#<#{self.class} running=#{@running.size} queued=#{@queue.size} limit=#{@limit} pgid=#{@pgid}>"
		end
		
		private
		
		# The waiting loop, schedule any outstanding tasks:
		def waiting
			@waiting = true
			
			# Schedule any queued tasks:
			schedule!
			
			yield
		ensure
			@waiting = false
		end
		
		def waiting?
			@waiting
		end
		
		# Append a process to the queue and schedule it for execution if possible.
		def append!(process)
			@queue << process
			
			schedule! if waiting?
			
			Fiber.yield
		end
		
		# Run any processes while space is available in the group.
		def schedule!
			while available? and @queue.size > 0
				process = @queue.shift
				
				if @running.size == 0
					pid = process.call(:pgroup => true)
					
					# The process group id is the pid of the first process:
					@pgid = pid
				else
					pid = process.call(:pgroup => @pgid)
				end
				
				if @terminal and process.foreground?
					@terminal.foreground = pid
				end
				
				@running[pid] = process
			end
		end
		
		# Wait for all children to exit but without resuming any controlling fibers.
		def wait_all
			wait_one while running?
			
			# Clear any queued tasks:
			@queue.clear
		end
		
		# Wait for one process, should only be called when a child process has finished, otherwise would block.
		def wait_one(flags = 0)
			raise RuntimeError.new("Process group has no running children!") unless running?
			
			# Wait for processes in this group:
			pid, status = Process.wait2(-@pgid, flags)
			
			return if flags & Process::WNOHANG and pid == nil
			
			process = @running.delete(pid)
			
			# This should never happen unless something very odd has happened:
			raise RuntimeError.new("Process id=#{pid} is not part of group!") unless process
			
			return process, status
		end
	end
end
