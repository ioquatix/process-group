# Process::Group

`Process::Group` allows for multiple fibers to run system processes concurrently with minimal overhead.

[![Build Status](https://secure.travis-ci.org/ioquatix/process-group.svg)](http://travis-ci.org/ioquatix/process-group)
[![Code Climate](https://codeclimate.com/github/ioquatix/process-group.svg)](https://codeclimate.com/github/ioquatix/process-group)
[![Coverage Status](https://coveralls.io/repos/ioquatix/process-group/badge.svg)](https://coveralls.io/r/ioquatix/process-group)
[![Documentation](http://img.shields.io/badge/yard-docs-blue.svg)](http://www.rubydoc.info/gems/process-group)
[![Code](http://img.shields.io/badge/github-code-blue.svg)](https://github.com/ioquatix/process-group)

## Installation

Add this line to your application's Gemfile:

```ruby
    gem 'process-group'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install process-group

## Usage

The simplest concurrent usage is as follows:

```ruby
# Create a new process group:
group = Process::Group.new

# Run the command (non-blocking):
group.run("sleep 1") do |exit_status|
	# Running in a separate fiber, will execute this code once the process completes:
	puts "Command finished with status: #{exit_status}"
end

# Do something else here:
sleep(1)

# Wait for all processes in group to finish:
group.wait
```

The `group.wait` call is an explicit synchronisation point, and if it completes successfully, all processes/fibers have finished successfully. If an error is raised in a fiber, it will be passed back out through `group.wait` and this is the only failure condition. Even if this occurs, all children processes are guaranteed to be cleaned up.

### Explicit Fibers

Items within a single fiber will execute sequentially. Processes (e.g. via `Group#spawn`) will run concurrently in multiple fibers.

```ruby
group = Process::Group.new

# Explicity manage concurrency in this fiber:
Fiber.new do
	# These processes will be run sequentially:
	group.spawn("sleep 1")
	group.spawn("sleep 1")
end.resume

# Implicitly run this task concurrently as the above fiber:
group.run("sleep 2")

# Wait for fiber to complete:
group.wait
```

`Group#spawn` is theoretically identical to `Process#spawn` except the processes are run concurrently if possible.

### Specify Options

You can specify options to `Group#run` and `Group#spawn` just like `Process::spawn`:

```ruby
group = Process::Group.new

env = {'FOO' => 'BAR'}

# Arguments are essentially the same as Process::spawn.
group.run(env, "sleep 1", chdir: "/tmp")

group.wait
```

### Process Limit

The process group can be used as a way to spawn multiple processes, but sometimes you'd like to limit the number of parallel processes to something relating to the number of processors in the system. A number of options exist.

```ruby
# 'facter' gem - found a bit slow to initialise, but most widely supported.
require 'facter'
group = Process::Group.new(limit: Facter.processorcount)

# 'system' gem - found very fast, less wide support (but nothing really important).
require 'system'
group = Process::Group.new(limit: System::CPU.count)

# hardcoded - set to n (8 < n < 32) and let the OS scheduler worry about it.
group = Process::Group.new(limit: 32)

# unlimited - default.
group = Process::Group.new
```

### Kill Group

It is possible to send a signal (kill) to the entire process group:

```ruby
group.kill(:TERM)
```

If there are no running processes, this is a no-op (rather than an error).

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
