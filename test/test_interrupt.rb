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

require 'test/unit'
require 'mocha/test_unit'

require 'process/group'

class TestInterrupt < Test::Unit::TestCase
	def test_raise_interrupt
		group = Process::Group.new
		checkpoint = ""
		
		Fiber.new do
			checkpoint += 'X'
			
			result = group.spawn("sleep 0.5")
			assert_equal 0, result
			
			checkpoint += 'Y'
			
			# Simulate the user pressing Ctrl-C after 0.5 seconds:
			raise Interrupt
		end.resume
		
		Fiber.new do
			checkpoint += 'A'
			
			# This never returns:
			result = group.spawn("sleep 1")
			
			checkpoint += 'B'
		end.resume
		
		group.expects(:kill).with(:INT).once
		group.expects(:kill).with(:TERM).once
		group.wait
		
		assert 'XYA', checkpoint
	end
	
	def test_raise_exception
		group = Process::Group.new
		checkpoint = ""
		
		Fiber.new do
			checkpoint += 'X'
			
			result = group.spawn("sleep 0.5")
			assert_equal 0, result
			
			checkpoint += 'Y'
			
			# Raises a RuntimeError
			fail "Error"
		end.resume
		
		Fiber.new do
			checkpoint += 'A'
			
			# This never returns:
			result = group.spawn("sleep 1")
			
			checkpoint += 'B'
		end.resume
		
		assert_raises RuntimeError do
			group.expects(:kill).with(:TERM).once
			
			group.wait
		end
		
		assert 'XYA', checkpoint
	end
end
