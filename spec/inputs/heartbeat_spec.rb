require "logstash/devutils/rspec/spec_helper"
require "logstash/devutils/rspec/shared_examples"
require "logstash/inputs/heartbeat"

describe LogStash::Inputs::Heartbeat do

  it_behaves_like "an interruptible input plugin" do
    let(:config) { { "interval" => 100 } }
  end

  before :each do
    subject.register
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
    subject { LogStash::Inputs::Heartbeat.new({"message" => "sequence", "ecs_compatibility" => :disabled}) }

    it "should return an event with the appropriate sequence value" do
      expect(subject.generate_message(sequence).get("clock")).to eq(sequence)
    end # it "should return an event with the appropriate sequence value"
  end # context "Sequence test"

  context "Epoch test" do
    subject { LogStash::Inputs::Heartbeat.new({"message" => "epoch", "ecs_compatibility" => :disabled}) }

    it "should return an event with the current time (as epoch)" do
      now = Time.now.to_i
      # Give it a second, just in case
      evt = subject.generate_message(sequence)
      expect(evt.get("clock") - now).to be < 2
      expect(evt).to_not include "message"
    end # it "should return an event with the current time (as epoch)"
  end # context "Epoch test"

  context "Epoch test with ECS enabled" do
    subject { LogStash::Inputs::Heartbeat.new({"sequence" => "epoch", "ecs_compatibility" => :v1}) }

    it "should return an event with the current time (as epoch)" do
      now = Time.now.to_i
      # Give it a second, just in case
      expect(subject.generate_message(sequence).get("[event][sequence]") - now).to be < 2
    end

    context "and message is defined with sequence selector" do
      subject { LogStash::Inputs::Heartbeat.new({"sequence" => "epoch", "message" => "sequence", "ecs_compatibility" => :v1}) }
      
      it "should return an event without the message field but populating the sequence field as requested by 'sequence' setting" do
        now = Time.now.to_i
        # Give it a second, just in case
        evt = subject.generate_message(sequence)
        expect(evt.get("[event][sequence]") - now).to be < 2
        expect(evt).to_not include "message"
      end
    end

    context "and message is defined with free text" do
      subject { LogStash::Inputs::Heartbeat.new({"sequence" => "epoch", "message" => "funny message", "ecs_compatibility" => :v1}) }

      it "should return an event without the message field but populating the sequence field as requested by 'sequence' setting" do
        now = Time.now.to_i
        # Give it a second, just in case
        evt = subject.generate_message(sequence)
        expect(evt.get("[event][sequence]") - now).to be < 2
        expect(evt.get("message")).to eq("funny message")
      end
    end
  end

  context "with a fixed count" do
    let(:events) { [] }
    let(:count) { 4 }

    context "ECS disabled" do
      subject { LogStash::Inputs::Heartbeat.new("interval" => 1, "message" => "sequence", "count" => count, "ecs_compatibility" => :disabled) }

      it "should generate a fixed number of events then stop" do
        subject.run(events)
        events.each_with_index{|event, i| expect(event.get("clock")).to eq(i + 1)}
      end
    end

    context "ECS enabled" do
      subject { LogStash::Inputs::Heartbeat.new("interval" => 1, "sequence" => "sequence", "count" => count, "ecs_compatibility" => :v1) }

      it "should generate a fixed number of events then stop" do
        subject.run(events)
        events.each_with_index{|event, i| expect(event.get("[event][sequence]")).to eq(i + 1)}
      end
    end
  end

  context "sequence settings test" do
      subject { LogStash::Inputs::Heartbeat.new({"sequence" => "epoch", "message" => "sequence", "ecs_compatibility" => :disabled}) }

      it "should return an event giving sequence precedence over message" do
        now = Time.now.to_i
        # Give it a second, just in case
        expect(subject.generate_message(sequence).get("clock") - now).to be < 2
      end # it "should return an event with the current time (as epoch)"
    end # context "Epoch test"
end
