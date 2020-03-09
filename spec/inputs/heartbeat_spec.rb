require "logstash/devutils/rspec/spec_helper"
require "logstash/devutils/rspec/shared_examples"
require "logstash/inputs/heartbeat"

describe LogStash::Inputs::Heartbeat do

  it_behaves_like "an interruptible input plugin" do
    let(:config) { { "interval" => 100 } }
  end

  sequence = 1
  context "Default message test" do
    subject { LogStash::Inputs::Heartbeat.new({}) }

    it "should generate an 'ok' message" do
      expect(subject.generate_message(sequence).get("message")).to eq('ok')
    end # it "should generate an 'ok' message"
  end # context "Default message test"

  context "Simple message test" do
    subject { LogStash::Inputs::Heartbeat.new({"message" => "my_message"}) }

    it "should generate a message containing 'my_message'" do
      expect(subject.generate_message(sequence).get("message")).to eq('my_message')
    end # it "should generate a message containing 'my_message'"
  end # context "Simple message test" do

  context "Sequence test" do
    subject { LogStash::Inputs::Heartbeat.new({"message" => "sequence"}) }

    it "should return an event with the appropriate sequence value" do
      expect(subject.generate_message(sequence).get("clock")).to eq(sequence)
    end # it "should return an event with the appropriate sequence value"
  end # context "Sequence test"

  context "Epoch test" do
    subject { LogStash::Inputs::Heartbeat.new({"message" => "epoch"}) }

    it "should return an event with the current time (as epoch)" do
      now = Time.now.to_i
      # Give it a second, just in case
      expect(subject.generate_message(sequence).get("clock") - now).to be < 2
    end # it "should return an event with the current time (as epoch)"
  end # context "Epoch test"

  context "with a fixed count" do
    let(:events) { [] }
    let(:count) { 4 }
    subject { LogStash::Inputs::Heartbeat.new("interval" => 1, "message" => "sequence", "count" => count) }

    it "should generate a fixed number of events then stop" do
      subject.run(events)
      events.each_with_index{|event, i| expect(event.get("clock")).to eq(i + 1)}
    end
  end
end
