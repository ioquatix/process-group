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

module Process
	# A group of tasks which can be run asynchrnously using fibers. Someone must call Group#wait to ensure that all fibers eventually resume.
	class Group
		class Command
			def initialize(arguments, options, fiber = Fiber.current)
				@arguments = arguments
				@options = options
			
				@fiber = fiber
			end
		
			attr :arguments
			attr :options
		
			def run(options = {})
				@pid = Process.spawn(*@arguments, @options.merge(options))
				
				return @pid
			end
		
			def resume(*arguments)
				@fiber.resume(*arguments)
			end
		end
		
		class Fork
			def initialize(block, options, fiber = Fiber.current)
				@options = options
				@block = block
				
				@fiber = fiber
			end
			
			def run(options = {})
				@pid = Process.fork(&@block)
				
				if options[:pgroup] == true
					# Establishes the child process as a process group leader:
					Process.setpgid(@pid, 0)
				else
					# Set this process as part of the existing process group:
					Process.setpgid(@pid, options[:pgroup])
				end
				
				return @pid
			end
		
			def resume(*arguments)
				@fiber.resume(*arguments)
			end
		end
		
		# Create a new process group. Can specify `options[:limit]` which limits the maximum number of concurrent processes.
		def initialize(options = {})
			@queue = []
			@limit = options[:limit]
		
			@running = {}
			@fiber = nil
		
			@pgid = nil
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

		def running?
			@running.size > 0
		end

		# Run a process, arguments have same meaning as Process#spawn.
		def run(*arguments)
			Fiber.new do
				exit_status = self.spawn(*arguments)
				
				yield exit_status if block_given?
			end.resume
		end
		
		def spawn(*arguments)
			# Could be nice to use ** splat, but excludes ruby < 2.0.
			options = Hash === arguments.last ? arguments.pop : {}
	
			append! Command.new(arguments, options)
		end
		
		def fork(options = {}, &block)
			append! Fork.new(block, options)
		end
		
		# Whether not not calling run would be scheduled immediately.
		def available?
			if @limit
				@running.size < @limit
			else
				true
			end
		end
		
		# Whether or not calling run would block the caller.
		def blocking?
			not available?
		end
		
		# Wait for all processes to finish, naturally would schedule any fibers which are currently blocked.
		def wait
			while running?
				process, status = wait_one
				
				schedule!
				
				process.resume(status)
			end
			
			# No processes, process group is no longer valid:
			@pgid = nil
		rescue Interrupt
			# If the user interrupts the wait, interrupt the process group and wait for them to finish:
			self.kill(:INT)
			
			# If user presses Ctrl-C again (or something else goes wrong), we will come out and kill(:TERM) in the ensure below:
			wait_all
			
			raise
		ensure
			# You'd only get here with running processes if some unexpected error was thrown:
			self.kill(:TERM)
			
			# Clean up zombie processes - if user presses Ctrl-C or for some reason something else blows up, exception would propagate back to caller:
			wait_all
		end
		
		# Send a signal to all processes.
		def kill(signal)
			if running?
				Process.kill(signal, id)
			end
		end
		
		private
		
		def append!(process)
			@queue << process
			
			schedule!
			
			Fiber.yield
		end
		
		# Run any processes while space is available in the group.
		def schedule!
			while available? and @queue.size > 0
				process = @queue.shift
			
				if @running.size == 0
					pid = process.run(:pgroup => true)
					
					# The process group id is the pid of the first process:
					@pgid = pid
				else
					pid = process.run(:pgroup => @pgid)
				end
			
				@running[pid] = process
			end
		end
		
		# Wait for all children to exit but without resuming any controlling fibers.
		def wait_all
			wait_one while running?
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
