defmodule Membrane.RTP.VP8.PayloadDescriptorTest do
  use ExUnit.Case
  alias Membrane.RTP.VP8.PayloadDescriptor

  describe "VP8 Payload Descriptor parsing tests" do
    @doc """
       X R N S R  PID
      +-+-+-+-+-+-----+
      |0|0|1|1|0|0 1 1| (51)
      +-+-+-+-+-+-----+
    """

    test "payload too short" do
      payload = <<51>>
      assert {:error, :payload_too_short} = PayloadDescriptor.parse_payload_descriptor(payload)
    end

    @doc """
     X R N S R  PID
    +-+-+-+-+-+-----+
    |0|1|1|1|0|0 1 1| (115) also 59=00111011 and 123=01111011
    +-+-+-+-+-+-----+
    |0 1 0 1 0 1 0 1| (sample rest of payload)
    +---------------+

    Payload is malformed because as RFC7741 points out that R field are reserved for future use and MUST be set to 0
    """
    test "R field not equal to 0" do
      payload_1 = <<115, 85>>
      payload_2 = <<59, 85>>
      payload_3 = <<123, 85>>

      assert {:error, :malformed_data} = PayloadDescriptor.parse_payload_descriptor(payload_1)
      assert {:error, :malformed_data} = PayloadDescriptor.parse_payload_descriptor(payload_2)
      assert {:error, :malformed_data} = PayloadDescriptor.parse_payload_descriptor(payload_3)
    end

    @doc """
     X R N S R  PID
    +-+-+-+-+-+-----+
    |0|0|1|1|0|0 1 1| (51)
    +-+-+-+-+-+-----+
    |0 1 0 1 0 1 0 1| (85 - sample rest of payload)
    +---------------+
    """
    test "only first mandatory octet" do
      payload = <<51, 85>>

      {:ok, {payload_descriptor, rest}} = PayloadDescriptor.parse_payload_descriptor(payload)

      expected_payload_descriptor = %PayloadDescriptor{x: 0, n: 1, s: 1, partition_index: 3}

      assert rest == <<85>>
      assert payload_descriptor == expected_payload_descriptor
    end

    @doc """
     X R N S R  PID
    +-+-+-+-+-+-+-+-+
    |1|0|1|1|0|0 1 1| (179)
    +-+-+-+-+-+-+-+-+
    |1|0|0|0|0 0 0 0| (128)
    +-+-+-+-+-+-+-+-+
    |0 1 0 1 0 1 0 1| (85 - single byte picture id)
    +-+-+-+-+-+-----+
    |0 1 0 1 0 1 0 1| (85 - sample rest of payload)
    +---------------+
    """

    test "extention bits and single byte picture id present" do
      payload = <<179, 128, 85, 85>>

      {:ok, {payload_descriptor, rest}} = PayloadDescriptor.parse_payload_descriptor(payload)

      expected_payload_descriptor = %PayloadDescriptor{
        x: 1,
        n: 1,
        s: 1,
        partition_index: 3,
        i: 1,
        picture_id: 85
      }

      assert rest == <<85>>
      assert payload_descriptor == expected_payload_descriptor
    end

    @doc """
     X R N S R  PID
    +-+-+-+-+-+-+-+-+
    |1|0|1|1|0|0 1 1| (179)
    +-+-+-+-+-+-+-+-+
    |1|0|0|0|0 0 0 0| (128)
    +-+-+-+-+-+-+-+-+
    |1 1 0 1 0 1 0 1| (213 - first byte od double byte picture ID. Note: most significant bit is set)
    +-+-+-+-+-+-----+
    |0 1 0 1 0 1 0 1| (85 - second byte of picture ID)
    +-+-+-+-+-+-+-+-+
    |0 1 0 1 0 1 0 1| (85 - sample rest of payload)
    +---------------+
    """

    test "extention bits and double byte picture id present" do
      payload = <<179, 128, 213, 85, 85>>

      {:ok, {payload_descriptor, rest}} = PayloadDescriptor.parse_payload_descriptor(payload)

      expected_payload_descriptor = %PayloadDescriptor{
        x: 1,
        n: 1,
        s: 1,
        partition_index: 3,
        i: 1,
        picture_id: 54_613
      }

      assert rest == <<85>>
      assert payload_descriptor == expected_payload_descriptor
    end

    @doc """
     X R N S R  PID
    +-+-+-+-+-+-+-+-+
    |1|0|1|1|0|0 1 1| (179)
    +-+-+-+-+-+-+-+-+
    |0|1|0|0|0 0 0 0| (64)
    +-+-+-+-+-+-+-+-+
    |0 1 0 1 0 1 0 1| (85 - TL0PICIDX)
    +-+-+-+-+-+-----+
    |0 1 0 1 0 1 0 1| (85 - sample rest of payload)
    +---------------+
    """

    test "extention bits and TL0PICIDX present" do
      payload = <<179, 64, 85, 85>>

      {:ok, {payload_descriptor, rest}} = PayloadDescriptor.parse_payload_descriptor(payload)

      expected_payload_descriptor = %PayloadDescriptor{
        x: 1,
        n: 1,
        s: 1,
        partition_index: 3,
        l: 1,
        tl0picidx: 85
      }

      assert rest == <<85>>
      assert payload_descriptor == expected_payload_descriptor
    end

    @doc """
     X R N S R  PID
    +-+-+-+-+-+-+-+-+
    |1|0|1|1|0|0 1 1| (179)
    +-+-+-+-+-+-+-+-+
    |0|1|0|0|0 0 0 0| (64)
    +-+-+-+-+-+-+-+-+
    |0 1 0 1 0 1 0 1| (85 - TID-Y-KEYIDX)
    +-+-+-+-+-+-----+
    |0 1 0 1 0 1 0 1| (85 - sample rest of payload)
    +---------------+
    """

    test "extention bits and TID-Y-KEYIDX present" do
      payload = <<179, 64, 85, 85>>

      {:ok, {payload_descriptor, rest}} = PayloadDescriptor.parse_payload_descriptor(payload)

      expected_payload_descriptor = %PayloadDescriptor{
        x: 1,
        n: 1,
        s: 1,
        partition_index: 3,
        l: 1,
        tl0picidx: 85
      }

      assert rest == <<85>>
      assert payload_descriptor == expected_payload_descriptor
    end

    @doc """
     X R N S R  PID
    +-+-+-+-+-+-+-+-+
    |1|0|1|1|0|0 1 1| (179)
    +-+-+-+-+-+-+-+-+
    |1|1|0|1|0 0 0 0| (208)
    +-+-+-+-+-+-+-+-+
    |1 1 0 1 0 1 0 1| (213 - first byte od double byte picture ID. Note: most significant bit is set)
    +-+-+-+-+-+-----+
    |0 1 0 1 0 1 0 1| (85 - second byte of picture ID)
    +-+-+-+-+-+-+-+-+
    |0 1 0 1 0 1 0 1| (85 - TL0PICIDX)
    +-+-+-+-+-+-----+
    |0 1 0 1 0 1 0 0| (84 - TID-Y-KEYIDX)
    +---------------+
    |1 0 1 0 1 0 1 0| (170 - sample rest of payload)
    +-+-+-+-+-+-+-+-+
    """

    test "extention bits, extended picture ID, TL0PICIDX and TID-Y-KEYIDX" do
      payload = <<179, 208, 213, 85, 85, 84, 170>>

      {:ok, {payload_descriptor, rest}} = PayloadDescriptor.parse_payload_descriptor(payload)

      expected_payload_descriptor = %PayloadDescriptor{
        x: 1,
        n: 1,
        s: 1,
        partition_index: 3,
        i: 1,
        l: 1,
        k: 1,
        picture_id: 54_613,
        tl0picidx: 85,
        tid: 1,
        keyidx: 20
      }

      assert rest == <<170>>
      assert payload_descriptor == expected_payload_descriptor
    end
  end
end
