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

class TestFork < MiniTest::Test
	def test_fork_io
		group = Process::Group.new
		
		input, output = IO.pipe
		
		Fiber.new do
			result = group.fork do
				output.puts "Hello World"
				
				exit(1)
			end
			
			assert_equal 1, result.exitstatus
		end.resume
		
		output.close
		
		group.wait
		
		assert_equal "Hello World\n", input.read
	end
	
	def test_fork_interrupt
		group = Process::Group.new
		
		Fiber.new do
			result = group.fork do
				raise Interrupt
			end
			
			refute_equal 0, result.exitstatus
		end.resume
		
		# Shouldn't raise any errors:
		group.wait
	end
end
