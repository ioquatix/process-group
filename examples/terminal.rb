#!/usr/bin/env ruby

require_relative '../lib/process/group'

group = Process::Group.new

5.times do
	Fiber.new do
		result = group.fork do
			begin
				sleep 1 while true
			rescue Interrupt
				puts "Interrupted in child #{Process.pid}"
			end
		end
	end.resume
end

begin
	group.wait
rescue Interrupt
	puts "Interrupted in parent #{Process.pid}"
end
