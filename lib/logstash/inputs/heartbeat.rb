# encoding: utf-8
require "logstash/inputs/threadable"
require "logstash/namespace"
require "stud/interval"
require "socket" # for Socket.gethostname
require "logstash/plugin_mixins/deprecation_logger_support"
require "logstash/plugin_mixins/ecs_compatibility_support"
require 'logstash/plugin_mixins/event_support/event_factory_adapter'

# Generate heartbeat messages.
#
# The general intention of this is to test the performance and
# availability of Logstash.
#

class LogStash::Inputs::Heartbeat < LogStash::Inputs::Threadable
  include LogStash::PluginMixins::DeprecationLoggerSupport
  include LogStash::PluginMixins::ECSCompatibilitySupport(:disabled, :v1, :v8 => :v1)
  include LogStash::PluginMixins::EventSupport::EventFactoryAdapter

  config_name "heartbeat"

  default :codec, "plain"

  # The message string to use in the event.
  #
  # If you set this to `epoch` then this plugin will use the current
  # timestamp in unix timestamp (which is by definition, UTC).  It will
  # output this value into a field called `clock`
  #
  # If you set this to `sequence` then this plugin will send a sequence of
  # numbers beginning at 0 and incrementing each interval.  It will
  # output this value into a field called `clock`
  #
  # Otherwise, this value will be used verbatim as the event message. It
  # will output this value into a field called `message`
  config :message, :validate => :string, :default => "ok"

  # Set how frequently messages should be sent.
  #
  # The default, `60`, means send a message every 60 seconds.
  config :interval, :validate => :number, :default => 60

  # How many times to iterate.
  # This is typically used only for testing purposes.
  config :count, :validate => :number, :default => -1

  # Select the type of sequence, deprecating the 'epoch' and 'sequence' values in 'message'.
  #
  # If you set this to `epoch` then this plugin will use the current
  # timestamp in unix timestamp (which is by definition, UTC).
  #
  # If you set this to `sequence` then this plugin will send a sequence of
  # numbers beginning at 0 and incrementing each interval.
  #
  # If you set this to 'none' then no field is created
  config :sequence, :validate => ["none", "epoch", "sequence"]

  def register
    @host = Socket.gethostname
    @field_sequence = ecs_select[disabled: "clock", v1: "[event][sequence]"]
    @field_host = ecs_select[disabled: "host", v1: "[host][name]"]
    if sequence.nil? && ["epoch", "sequence"].include?(message)
      logger.warn("message contains sequence type specification (epoch|sequence) for this purpose use the sequence option")
    end
    if ecs_compatibility == :disabled && @sequence.nil?
      if %w(epoch sequence).include?(@message)
        logger.debug("intercepting magic `message` to configure `sequence`: `#{@message}`")
        @sequence, @message = @message, nil # legacy: intercept magic messages
        deprecation_logger.deprecated("magic values of `message` to specify sequence type are deprecated; use separate `sequence` option instead.")
      end
    end
    @sequence = "none" if @sequence.nil?
    @sequence_selector = @sequence.to_sym
  end

  def run(queue)
    sequence_count = 0

    while !stop?
      start = Time.now

      sequence_count += 1
      event = generate_message(sequence_count)
      decorate(event)
      queue << event
      break if sequence_count == @count || stop?

      sleep_for = @interval - (Time.now - start)
      Stud.stoppable_sleep(sleep_for) { stop? } if sleep_for > 0
    end
  end

  def generate_message(sequence_count)
    if @sequence_selector == :none
      evt = event_factory.new_event("message" => @message)
      evt.set(@field_host, @host)
      return evt
    end

    sequence_value = @sequence_selector == :epoch ? Time.now.to_i : sequence_count
    evt = event_factory.new_event()
    evt.set(@field_sequence, sequence_value)
    evt.set(@field_host, @host)
    evt.set("message", @message) unless @message.nil?
    evt
  end
end
