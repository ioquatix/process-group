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
	it "should invoke child task normally" do
		child_exit_status = nil
		
		subject.wait do
			subject.run("exit 0") do |exit_status|
				child_exit_status = exit_status
			end
		end
		
		expect(child_exit_status).to be == 0
	end
	
	it "should kill child task if process is interrupted" do
		child_exit_status = nil
		
		expect do
			subject.wait do
				subject.run("sleep 10") do |exit_status|
					child_exit_status = exit_status
				end
				
				# Simulate the parent (controlling) process receiving an interrupt.
				raise Interrupt
			end
		end.to raise_error(Interrupt)
		
		expect(child_exit_status).to_not be == 0
	end
	
	it "should propagate Interrupt" do
		expect(Process::Group).to receive(:new).once.and_call_original
		
		expect do
			Process::Group.wait do |group|
				raise Interrupt
			end
		end.to raise_error(Interrupt)
	end
	
	it "should clear queue after wait" do
		subject.limit = 1
		
		subject.run("sleep 10")
		subject.run("sleep 10")
		
		expect(subject.running?).to be_falsey
		expect(subject.queued?).to be_truthy
		
		expect do
			subject.wait do
				raise Interrupt
			end
		end.to raise_error(Interrupt)
		
		expect(subject.running?).to be_falsey
		expect(subject.queued?).to be_falsey
	end
end
