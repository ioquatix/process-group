# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'minitest/autorun'

require 'process/group'

class TestSpawn < MiniTest::Test
	def test_fibers
		group = Process::Group.new
		
		start_time = Time.now
		
		Fiber.new do
			result = group.fork { sleep 1.0 }
			
			assert_equal 0, result
		end.resume
		
		Fiber.new do
			result = group.fork { sleep 2.0 }
			
			assert_equal 0, result
		end.resume
		
		group.wait
		
		end_time = Time.now
		
		# Check that the execution time was roughly 2 seconds:
		assert (1.9..2.1).include?(end_time - start_time)
	end
	
	def test_kill_commands
		group = Process::Group.new
		
		start_time = Time.now
		
		group.run("sleep 1") do |exit_status|
			refute_equal 0, exit_status
		end
		
		group.run("sleep 2") do |exit_status|
			refute_equal 0, exit_status
		end
		
		group.kill(:KILL)
		
		group.wait
		
		end_time = Time.now
		
		# Check that processes killed almost immediately:
		assert (end_time - start_time) < 0.1
	end
	
	def test_environment_options
		group = Process::Group.new
		
		env = {'FOO' => 'BAR'}
		
		# Make a pipe to receive output from child process:
		input, output = IO.pipe
		
		group.run(env, "echo $FOO", out: output) do |exit_status|
			output.close
		end
		
		group.wait
		
		assert_equal "BAR\n", input.read
	end
	
	def test_yield
		group = Process::Group.new
		
		start_time = Time.now
		
		group.run("sleep 1")
		
		group.run("sleep 1") do |exit_status|
		end
		
		group.wait
		
		end_time = Time.now
		
		# Check that the execution time was roughly 1 second:
		assert (0.9..1.1).include?(end_time - start_time)
	end
end
