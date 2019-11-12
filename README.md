# Process::Group

`Process::Group` allows for multiple fibers to run system processes concurrently with minimal overhead.

```ruby
Process::Group.wait do |group|
	group.run("ls", "-lah") {|status| puts status.inspect}
	group.run("echo", "Hello World") {|status| puts status.inspect}
end
```

[![Build Status](https://secure.travis-ci.com/socketry/process-group.svg)](http://travis-ci.com/socketry/process-group)
[![Coverage Status](https://coveralls.io/repos/socketry/process-group/badge.svg)](https://coveralls.io/r/socketry/process-group)
[![Documentation](http://img.shields.io/badge/yard-docs-blue.svg)](http://www.rubydoc.info/gems/process-group)
[![Code](http://img.shields.io/badge/github-code-blue.svg)](https://github.com/socketry/process-group)

## Installation

Add this line to your application's Gemfile:

	gem 'process-group'

And then execute:

	$ bundle

Or install it yourself as:

	$ gem install process-group

## Usage

The simplest concurrent usage is as follows:

	# Create a new process group:
	Process::Group.wait do |group|
		# Run the command (non-blocking):
		group.run("sleep 1") do |exit_status|
			# Running in a separate fiber, will execute this code once the process completes:
			puts "Command finished with status: #{exit_status}"
		end
		
		# Do something else here:
		sleep(1)
		
		# Wait for all processes in group to finish.
	end

The `group.wait` call is an explicit synchronization point, and if it completes successfully, all processes/fibers have finished successfully. If an error is raised in a fiber, it will be passed back out through `group.wait` and this is the only failure condition. Even if this occurs, all children processes are guaranteed to be cleaned up.

### Explicit Fibers

Items within a single fiber will execute sequentially. Processes (e.g. via `Group#spawn`) will run concurrently in multiple fibers.

```ruby
Process::Group.wait do |group|
	# Explicity manage concurrency in this fiber:
	Fiber.new do
		# These processes will be run sequentially:
		group.spawn("sleep 1")
		group.spawn("sleep 1")
	end.resume

	# Implicitly run this task concurrently as the above fiber:
	group.run("sleep 2")
end
```

`Group#spawn` is theoretically identical to `Process#spawn` except the processes are run concurrently if possible.

### Explicit Wait

The recommended approach to use process group is to call `Process::Group.wait` with a block which invokes tasks. This block is wrapped in appropriate `rescue Interrupt` and `ensure` blocks which guarantee that the process group is cleaned up:

```ruby
Process::Group.wait do |group|
	group.run("sleep 10")
end
```

It is also possible to invoke this machinery and reuse the process group simply by instantiating the group and calling wait explicitly:

```ruby
group = Process::Group.new

group.wait do
	group.run("sleep 10")
end
```

It is also possible to queue tasks for execution outside the wait block. But by design, it's only possible to execute tasks within the wait block. Tasks added outside a wait block will be queued up for execution when `#wait` is invoked:

```ruby
group = Process::Group.new

group.run("sleep 10")

# Run command here:
group.wait
```

### Specify Options

You can specify options to `Group#run` and `Group#spawn` just like `Process::spawn`:

```ruby
Process::Group.wait do |group|
	env = {'FOO' => 'BAR'}
	
	# Arguments are essentially the same as Process::spawn.
	group.run(env, "sleep 1", chdir: "/tmp")
end
```

### Process Limit

The process group can be used as a way to spawn multiple processes, but sometimes you'd like to limit the number of parallel processes to something relating to the number of processors in the system. By default, there is no limit on the number of processes running concurrently.

```ruby
# limit based on the number of processors:
require 'etc'
group = Process::Group.new(limit: Etc.nprocessors)

# hardcoded - set to n (8 < n < 32) and let the OS scheduler worry about it:
group = Process::Group.new(limit: 32)

# unlimited - default:
group = Process::Group.new
```

### Kill Group

It is possible to send a signal (kill) to the entire process group:

```ruby
group.kill(:TERM)
```

If there are no running processes, this is a no-op (rather than an error). [Proper handling of SIGINT/SIGQUIT](http://www.cons.org/cracauer/sigint.html) explains how to use signals correctly.

#### Handling Interrupts

`Process::Group` transparently handles `Interrupt` when raised within a `Fiber`. If `Interrupt` is raised, all children processes will be sent `kill(:INT)` and we will wait for all children to complete, but without resuming the controlling fibers. If `Interrupt` is raised during this process, children will be sent `kill(:TERM)`. After calling `Interrupt`, the fibers will not be resumed.

### Process Timeout

You can run a process group with a time limit by using a separate child process:

```ruby
group = Process::Group.new

class Timeout < StandardError
end

Fiber.new do
	# Wait for 2 seconds, let other processes run:
	group.fork { sleep 2 }
	
	# If no other processes are running, we are done:
	Fiber.yield unless group.running?
	
	# Send SIGINT to currently running processes:
	group.kill(:INT)
	
	# Wait for 2 seconds, let other processes run:
	group.fork { sleep 2 }
	
	# If no other processes are running, we are done:
	Fiber.yield unless group.running?
	
	# Send SIGTERM to currently running processes:
	group.kill(:TERM)
	
	# Raise an Timeout exception which is based back out:
	raise Timeout
end.resume

# Run some other long task:
group.run("sleep 10")

# Wait for fiber to complete:
begin
	group.wait
rescue Timeout
	puts "Process group was terminated forcefully."
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Released under the MIT license.

Copyright, 2014, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
