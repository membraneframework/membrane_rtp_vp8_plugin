/* Decoder state exactly parallels that of the encoder.
      "value", together with the remaining input, equals the
      complete encoded number x less the left endpoint of the
      current coding interval. */
#include <stdio.h>
#include <stdlib.h>

typedef struct
{
  uint8_t *input;  /* pointer to next compressed data byte */
  uint32_t range;  /* always identical to encoder's range */
  uint32_t value;  /* contains at least 8 significant bits */
  int bit_count; /* # of bits shifted out of
                            value, at most 7 */
} bool_decoder;

/* Call this function before reading any bools from the
      partition. */

void init_bool_decoder(bool_decoder *d, uint8_t *start_partition)
{
  {
    int i = 0;
    d->value = 0; /* value = first 2 input bytes */
    while (++i <= 2)

      d->value = (d->value << 8) | *start_partition++;
  }

  d->input = start_partition; /* ptr to next byte to be read */
  d->range = 255;             /* initial range is full */
  d->bit_count = 0;           /* have not yet shifted out any bits */
}

/* Main function reads a bool encoded at probability prob/256,
      which of course must agree with the probability used when the
      bool was written. */

int read_bool(bool_decoder *d, uint8_t prob)
{
  /* range and split are identical to the corresponding values
        used by the encoder when this bool was written */

  uint32_t split = 1 + (((d->range - 1) * prob) >> 8);
  uint32_t SPLIT = split << 8;
  int retval; /* will be 0 or 1 */
  if (d->value >= SPLIT)
  { /* encoded a one */
    retval = 1;
    d->range -= split; /* reduce range */
    d->value -= SPLIT; /* subtract off left endpoint of interval */
  }
  else
  { /* encoded a zero */
    retval = 0;
    d->range = split; /* reduce range, no change in left endpoint */
  }

  while (d->range < 128)
  { /* shift out irrelevant value bits */
    d->value <<= 1;
    d->range <<= 1;
    if (++d->bit_count == 8)
    { /* shift in new bits 8 at a time */
      d->bit_count = 0;
      d->value |= *d->input++;
    }
  }

  printf("%d ", retval);

  return retval;
}

/* Convenience function reads a "literal", that is, a "num_bits"-
      wide unsigned value whose bits come high- to low-order, with
      each bit encoded at probability 128 (i.e., 1/2). */

uint32_t read_literal(bool_decoder *d, int num_bits)
{
  uint32_t v = 0;

  while (num_bits--)
    v = (v << 1) + read_bool(d, 128);
  return v;
}

/* Variant reads a signed number */

int32_t read_signed_literal(bool_decoder *d, int num_bits)
{
  int32_t v = 0;
  if (!num_bits)
    return 0;
  if (read_bool(d, 128))
    v = -1;
  while (--num_bits)
    v = (v << 1) + read_bool(d, 128);
  return v;
}

void decode(){
  int i;
  uint8_t input[49] = {19, 17, 252, 0, 24, 0, 24, 88, 47, 244, 20, 48, 242, 224, 250, 60, 175, 16,
  36, 64, 128, 0, 32, 0, 4, 0, 1, 45, 166, 218, 45, 152, 216, 237, 126, 214,
  109, 70, 209, 140, 230, 200, 108, 54, 183, 106, 182, 148, 104};

  bool_decoder* bc = malloc(sizeof(bool_decoder));

  init_bool_decoder(bc, input); 

  if (1) {
    /* color space (1 bit) and clamping type (1 bit) */
    read_bool (bc, 128);
    read_bool (bc, 128);
  }

  /* segmentation_enabled */
  if (read_bool (bc, 128)) {
    uint8_t update_mb_segmentation_map = read_bool (bc, 128);
    uint8_t update_segment_feature_data = read_bool (bc, 128);

    if (update_segment_feature_data) {
      /* skip segment feature mode */
      read_bool (bc, 0x80);

      /* quantizer update */
      for (i = 0; i < 4; i++) {
        /* skip flagged quantizer value (7 bits) and sign (1 bit) */
        if (read_bool (bc, 128))
          read_literal (bc, 8);
      }

      /* loop filter update */
      for (i = 0; i < 4; i++) {
        /* skip flagged lf update value (6 bits) and sign (1 bit) */
        if (read_bool (bc, 128))
          read_literal (bc, 7);
      }
    }

    if (update_mb_segmentation_map) {
      /* segment prob update */
      for (i = 0; i < 3; i++) {
        /* skip flagged segment prob */
        if (read_bool (bc, 128))
          read_literal (bc, 8);
      }
    }
  }

  /* skip filter type (1 bit), loop filter level (6 bits) and
   * sharpness level (3 bits) */
  read_literal (bc, 1);
  read_literal (bc, 6);
  read_literal (bc, 3);

  /* loop_filter_adj_enabled */
  if (read_bool (bc, 128)) {

    /* delta update */
    if (read_bool (bc, 128)) {

      for (i = 0; i < 8; i++) {
        /* 8 updates, 1 bit indicate whether there is one and if follow by a
         * 7 bit update */
        if (read_bool (bc, 128))
          read_literal (bc, 7);
      }
    }
  }

  read_literal(bc, 2);
}


int main() {

  decode();
  // uint8_t input[10] = {65, 54, 37, 13, 21};

  // bool_decoder* bd = malloc(sizeof(bool_decoder));

  // init_bool_decoder(bd, input);



  // printf("Bool decoder: input_value: %d, value: %d, range: %d, bit_count: %d \r\n", *bd->input, bd->value, bd->range, bd->bit_count);

  // int bit = 0;
  // for (int i = 0; i < 24; i++) {
  //   bit = read_bool(bd, 128);
  //   printf("Bit: %d\r\n", bit);
  // }
}