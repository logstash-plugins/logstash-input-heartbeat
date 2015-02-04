require "logstash/devutils/rspec/spec_helper"
require "logstash/inputs/heartbeat"

def fetch_event(config, number)
  pipeline = LogStash::Pipeline.new(config)
  queue = Queue.new
  pipeline.instance_eval do
    @output_func = lambda { |event| queue << event }
  end
  pipeline_thread = Thread.new { pipeline.run }
  counter = 0
  begin
    event = queue.pop
    pipeline_thread.join
    counter += 1
  end until counter == number
  return event
end

describe LogStash::Inputs::Heartbeat do
  context "Default message test" do
    subject do
      next LogStash::Inputs::Heartbeat.new({})
    end

    it "should generate an 'ok' message" do
      sequence = 1
      subject.generate_message(sequence) do |event|
        insist { event['message'] } == 'ok'
      end
    end # it "should generate an 'ok' message"
  end # context "Default message test"

  context "Simple message test" do
    subject do
      next LogStash::Inputs::Heartbeat.new({"message" => "my_message"})
    end

    it "should generate a message containing 'my_message'" do
      sequence = 2
      subject.generate_message(sequence) do |event|
        insist { event['message'] } == 'my_message'
      end
    end # it "should generate a message containing 'my_message'"
  end # context "Simple message test" do

  context "Sequence test" do
    subject do
      next LogStash::Inputs::Heartbeat.new({"message" => "sequence"})
    end

    it "should return an event with the appropriate sequence value" do
      sequence = 3
      subject.generate_message(sequence) do |event|
        insist { event['clock'] } == sequence
      end
    end # it "should return an event with the appropriate sequence value"
  end # context "Sequence test"

  context "Epoch test" do
    subject do
      next LogStash::Inputs::Heartbeat.new({"message" => "epoch"})
    end

    it "should return an event with the current time (as epoch)" do
      sequence = 4
      now = Time.now.to_i
      subject.generate_message(sequence) do |event|
        # Give it a second, just in case
        insist { event['clock'] - now } < 2
      end
    end # it "should return an event with the current time (as epoch)"
  end # context "Epoch test"
end

describe "inputs/heartbeat" do
  count = 4
  it "should generate #{count} events then stop" do
    config = <<-CONFIG
      input {
        heartbeat {
          interval => 1
          message => "sequence"
          count => #{count}
        }
      }
    CONFIG

    event = fetch_event(config, count)
    insist { event['clock'] } == count
  end
end
