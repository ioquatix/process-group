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

require 'process/group'

RSpec.describe Process::Group do
	it "should raise interrupt exception" do
		checkpoint = ""
		
		Fiber.new do
			checkpoint += 'X'
		
			result = subject.fork { sleep 0.1 }
		
			expect(result).to be == 0
		
			checkpoint += 'Y'
		
			# Simulate the user pressing Ctrl-C after a short time:
			raise Interrupt
		end.resume
	
		Fiber.new do
			checkpoint += 'A'
			
			# This never returns:
			result = subject.fork do
				# We do this to exit immediately.. otherwise Ruby will print a backtrace and that's a bit confusing.
				trap(:INT) { exit!(0) }
				sleep(0.2)
			end
		
			checkpoint += 'B'
		end.resume
	
		expect(subject).to receive(:kill).with(:INT).once.and_call_original
		expect(subject).to receive(:kill).with(:TERM).once.and_call_original
		
		expect do
			subject.wait
		end.to raise_error(Interrupt)
		
		expect(checkpoint).to be == 'XAY'
	end
	
	it "should raise an exception" do
		checkpoint = ""
	
		Fiber.new do
			checkpoint += 'X'
		
			result = subject.fork { sleep 0.1 }
			expect(result).to be == 0
		
			checkpoint += 'Y'
		
			# Raises a RuntimeError
			fail "Error"
		end.resume
	
		Fiber.new do
			checkpoint += 'A'
		
			# This never returns:
			result = subject.fork { sleep 0.2 }
		
			checkpoint += 'B'
		end.resume
	
		expect do
			expect(subject).to receive(:kill).with(:TERM).once
		
			subject.wait
		end.to raise_error(RuntimeError)
	
		expect(checkpoint).to be == 'XAY'
	end

	it "should pass back out exceptions" do
		checkpoint = ""
	
		Fiber.new do
			# Wait for 2 seconds, let other processes run:
			subject.fork { sleep 2 }
			checkpoint += 'A'
			#puts "Finished waiting #1..."
	
			# If no other processes are running, we are done:
			Fiber.yield unless subject.running?
			checkpoint += 'B'
			#puts "Sending SIGINT..."
	
			# Send SIGINT to currently running processes:
			subject.kill(:INT)
	
			# Wait for 2 seconds, let other processes run:
			subject.fork { sleep 2 }
			checkpoint += 'C'
			#puts "Finished waiting #2..."
	
			# If no other processes are running, we are done:
			Fiber.yield unless subject.running?
			checkpoint += 'D'
			#puts "Sending SIGTERM..."
	
			# Send SIGTERM to currently running processes:
			subject.kill(:TERM)

			# Raise an Timeout exception which is pased back out:
			raise StandardError.new("Should never get here!")
		end.resume

		# Run some other long task:
		subject.run("sleep 10")
	
		start_time = Time.now
	
		# Wait for fiber to complete:
		expect do
			subject.wait
			checkpoint += 'E'
		end.not_to raise_error
	
		end_time = Time.now
	
		expect(checkpoint).to be == 'ABCE'
		expect(end_time - start_time).to be_within(0.2).of 4.0
	end
end
