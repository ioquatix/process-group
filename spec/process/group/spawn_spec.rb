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

module Process::Group::SpawnSpec
	describe Process::Group do
		it "should execute fibers concurrently" do
			group = Process::Group.new
			
			start_time = Time.now
			
			Fiber.new do
				result = group.fork { sleep 1.0 }
				
				expect(result).to be == 0
			end.resume
			
			Fiber.new do
				result = group.fork { sleep 2.0 }
				
				expect(result).to be == 0
			end.resume
			
			group.wait
			
			end_time = Time.now
			
			# Check that the execution time was roughly 2 seconds:
			expect(end_time - start_time).to be_within(0.1).of(2.0)
		end
		
		it "should kill commands" do
			group = Process::Group.new
		
			start_time = Time.now
		
			group.run("sleep 1") do |exit_status|
				expect(exit_status).to_not be 0
			end
		
			group.run("sleep 2") do |exit_status|
				expect(exit_status).to_not be 0
			end
		
			group.kill(:KILL)
		
			group.wait
		
			end_time = Time.now
		
			# Check that processes killed almost immediately:
			expect(end_time - start_time).to be < 0.2
		end
		
		it "should pass environment to child process" do
			group = Process::Group.new
		
			env = {'FOO' => 'BAR'}
		
			# Make a pipe to receive output from child process:
			input, output = IO.pipe
		
			group.run(env, "echo $FOO", out: output) do |exit_status|
				output.close
			end
		
			group.wait
		
			expect(input.read).to be == "BAR\n"
		end
		
		it "should yield exit status" do
			group = Process::Group.new
		
			start_time = Time.now
		
			group.run("sleep 1")
		
			group.run("sleep 1") do |exit_status|
				expect(exit_status).to be == 0
			end
		
			group.wait
		
			end_time = Time.now
		
			# Check that the execution time was roughly 1 second:
			expect(end_time - start_time).to be_within(0.1).of(1.0)
		end
	end
end
