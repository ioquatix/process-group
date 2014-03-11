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
				Process.spawn(*@arguments, @options.merge(options))
			end
		
			def resume(*arguments)
				@fiber.resume(*arguments)
			end
		end
		
		# Create a new process group. Can specify `options[:limit]` which limits the maximum number of concurrent processes.
		def initialize(options = {})
			@commands = []
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
	
			@commands << Command.new(arguments, options)
	
			schedule!
	
			Fiber.yield
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
			while @running.size > 0
				# Wait for processes in this group:
				pid, status = Process.wait2(-@pgid)
			
				command = @running.delete(pid)
			
				raise RuntimeError.new("Process #{pid} is not part of group!") unless command
			
				schedule!
			
				command.resume(status)
			end
		end
		
		# Send a signal to all processes.
		def kill(signal)
			if @running.size > 0
				Process.kill(signal, id)
			end
		end
		
		private
		
		# Run any commands while space is available in the group.
		def schedule!
			while available? and @commands.size > 0
				command = @commands.shift
			
				if @running.size == 0
					pid = command.run(:pgroup => true)
					@pgid = Process.getpgid(pid)
				else
					pid = command.run(:pgroup => @pgid)
				end
			
				@running[pid] = command
			end
		end
	end
end
