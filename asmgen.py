#!/usr/bin/env python

# system packages
import sys
import os
import argparse
import re

# external packages
import png  # package name is "pypng" on pypi.python.org
import numpy as np




def slugify(s):
    """Simplifies ugly strings into something that can be used as an assembler
    label.

    >>> print slugify("[Some] _ Article's Title--")
    SOME_ARTICLES_TITLE

    From https://gist.github.com/dolph/3622892#file-slugify-py
    """

    # "[Some] _ Article's Title--"
    # "[SOME] _ ARTICLE'S TITLE--"
    s = s.upper()

    # "[SOME] _ ARTICLE'S_TITLE--"
    # "[SOME]___ARTICLE'S_TITLE__"
    for c in [' ', '-', '.', '/']:
        s = s.replace(c, '_')

    # "[SOME]___ARTICLE'S_TITLE__"
    # "SOME___ARTICLES_TITLE__"
    s = re.sub('\W', '', s)

    # "SOME___ARTICLES_TITLE__"
    # "SOME   ARTICLES TITLE  "
    s = s.replace('_', ' ')

    # "SOME   ARTICLES TITLE  "
    # "SOME ARTICLES TITLE "
    s = re.sub('\s+', ' ', s)

    # "SOME ARTICLES TITLE "
    # "SOME ARTICLES TITLE"
    s = s.strip()

    # "SOME ARTICLES TITLE"
    # "SOME_ARTICLES_TITLE"
    s = s.replace(' ', '_')

    return s


class AssemblerSyntax(object):
    extension = "s"
    comment_char = ";"
    comma_string = ", "
    use_16_bit = False

    def asm(self, text):
        return "\t%s" % text

    def comment(self, text):
        return "\t%s %s" % (self.comment_char, text)

    def label(self, text):
        return text

    def byte(self, text):
        return self.asm(".byte %s" % text)

    def word(self, text):
        return self.asm(".word %s" % text)

    def address(self, text):
        return self.asm(".addr %s" % text)

    def origin(self, text):
        return self.asm("*= %s" % text)

    def include(self, text):
        return self.asm(".include \"%s\"" % text)

    def binary_constant(self, value):
        try:
            # already a string
            _ = len(value)
            return "#%%%s" % value
        except TypeError:
            return "#%%%s" % format(value, "08b")


class Mac65(AssemblerSyntax):
    def address(self, text):
        return self.asm(".word %s" % text)

    def binary_constant(self, value):
        try:
            # a string
            value = int(value, 2)
        except TypeError:
            pass
        return "#~%s" % format(value, "08b")


class CC65(AssemblerSyntax):
    extension = "s"

    def label(self, text):
        return "%s:" % text


class CSource(AssemblerSyntax):
    extension = "c"
    use_16_bit = True

    def label(self, text):
        return f"{text} = "

class Merlin(AssemblerSyntax):
    extension = "S"
    comma_string = ","

    def byte(self, text):
        return self.asm("db %s" % text)

    def word(self, text):
        return self.asm("dw %s" % text)

    def address(self, text):
        return self.asm("da %s" % text)

    def origin(self, text):
        return self.asm("org %s" % text)   

    def include(self, text):
        return self.asm("PUT %s" % text)

class Listing(object):
    def __init__(self, assembler, slug="asmgen-driver"):
        self.assembler = assembler
        self.lines = []
        self.current = None
        self.desired_count = 1
        self.stash_list = []
        self.slug = slug

    def __str__(self):
        self.flush_stash()
        return "\n".join(self.lines) + "\n"

    def add_listing(self, other):
        self.lines.extend(other.lines)

    def get_filename(self, basename):
        return "%s-%s.%s" % (basename, self.slug.lower(), self.assembler.extension)

    def write(self, basename, disclaimer):
        filename = self.get_filename(basename)
        print(f"Writing to {filename}")
        with open(filename, "w") as fh:
            fh.write(disclaimer + "\n\n")
            fh.write(str(self))
        return filename

    def out(self, line=""):
        self.flush_stash()
        self.lines.append(line)

    def out_append_last(self, line):
        self.lines[-1] += line

    def pop_asm(self, cmd=""):
        self.flush_stash()
        if cmd:
            search = self.assembler.asm(cmd)
            i = -1
            while self.lines[i].strip().startswith(self.assembler.comment_char):
                i -= 1
            if self.lines[i] == search:
                self.lines.pop(i)
        else:
            self.lines.pop(-1)

    def label(self, text):
        self.out(self.assembler.label(text))

    def comment(self, text):
        self.out_append_last(self.assembler.comment(text))

    def comment_line(self, text):
        self.out(self.assembler.comment(text))

    def asm(self, text):
        self.out(self.assembler.asm(text))

    def addr(self, text):
        self.out(self.assembler.address(text))

    def include(self, text):
        self.out(self.assembler.include(text))

    def flush_stash(self):
        if self.current is not None and len(self.stash_list) > 0:
            self.lines.append(self.current(self.assembler.comma_string.join(self.stash_list)))
        self.current = None
        self.stash_list = []
        self.desired_count = 1

    def stash(self, desired, text, per_line):
        if self.current is not None and (self.current != desired or per_line == 1):
            self.flush_stash()
        if per_line > 1:
            if self.current is None:
                self.current = desired
                self.desired_count = per_line
            self.stash_list.append(text)
            if len(self.stash_list) >= self.desired_count:
                self.flush_stash()
        else:
            self.out(desired(text))

    def binary_constant(self, value):
        return self.assembler.binary_constant(value)

    def byte(self, text, per_line=1):
        self.stash(self.assembler.byte, text, per_line)

    def word(self, text, per_line=1):
        self.stash(self.assembler.word, text, per_line)


class Sprite(Listing):
    backing_store_sizes = set()

    def __init__(self, slug, pngdata, assembler, screen, xdraw=False, use_mask=False, backing_store=False, clobber=False, double_buffer=False, damage=False, processor="any"):
        Listing.__init__(self, assembler)
        self.slug = slug
        self.screen = screen

        self.xdraw = xdraw
        self.use_mask = use_mask
        self.backing_store = backing_store
        self.clobber = clobber
        self.double_buffer = double_buffer
        self.damage = damage
        self.processor = processor
        self.width = pngdata[0]
        self.height = pngdata[1]
        self.pixel_data = list(pngdata[2])
        self.jump_table()
        for i in range(self.screen.num_shifts):
            self.blit_shift(i)

    def jump_table(self):
        # Prologue
        self.label("%s" % self.slug)
        self.comment("%d bytes per row" % self.screen.byte_width(self.width))

        if self.processor == "any":
            self.out(".ifpC02")
            self.jump65C02()
            self.out(".else")
            self.jump6502()
            self.out(".endif")
        elif self.processor == "65C02":
            self.jump65C02()
        elif self.processor == "6502":
            self.jump6502()
        else:
            raise RuntimeError("Processor %s not supported" % self.processor)

    def save_axy_65C02(self):
        self.asm("pha")
        self.asm("phx")
        self.asm("phy")

    def restore_axy_65C02(self):
        self.asm("ply")
        self.asm("plx")
        self.asm("pla")

    def save_axy_6502(self):
        self.asm("pha")
        self.asm("txa")
        self.asm("pha")
        self.asm("tya")
        self.asm("pha")

    def restore_axy_6502(self):
        self.asm("pla")
        self.asm("tay")
        self.asm("pla")
        self.asm("tax")
        self.asm("pla")

    def jump65C02(self):
        if not self.clobber:
            self.save_axy_65C02()
        self.asm("ldy param_x")
        self.asm("ldx MOD%d_%d,y" % (self.screen.num_shifts, self.screen.bits_per_pixel))

        self.asm("jmp (%s_JMP,x)\n" % (self.slug))
        offset_suffix = ""
        
        # Bit-shift jump table for 65C02
        self.label("%s_JMP" % (self.slug))
        for shift in range(self.screen.num_shifts):
            self.addr("%s_SHIFT%d" % (self.slug, shift))

    def jump6502(self):
        if not self.clobber:
            self.save_axy_6502()
        self.asm("ldy param_x")
        self.asm("ldx MOD%d_%d,y" % (self.screen.num_shifts, self.screen.bits_per_pixel))

        # Fast jump table routine; faster and smaller than self-modifying code
        self.asm("lda %s_JMP+1,x" % (self.slug))
        self.asm("pha")
        self.asm("lda %s_JMP,x" % (self.slug))
        self.asm("pha")
        self.asm("rts\n")

        # Bit-shift jump table for generic 6502
        self.label("%s_JMP" % (self.slug))
        for shift in range(self.screen.num_shifts):
            self.addr("%s_SHIFT%d-1" % (self.slug,shift))

    def blit_shift(self, shift):
        # Blitting functions
        self.out("\n")
        
        # Track cycle count of the blitter. We start with fixed overhead:
        # SAVE_AXY + RESTORE_AXY + rts +    sprite jump table
        cycle_count = 9 + 12 + 6 +   3 + 4 + 6
    
        baselabel = "%s_SHIFT%d" % (self.slug,shift)
        self.label(baselabel)

        color_streams = self.screen.byte_streams_from_pixels(shift, self)
        mask_streams = self.screen.byte_streams_from_pixels(shift, self, True)
        for c, m in zip(color_streams, mask_streams):
            self.comment_line(str(c) + "  " + str(m))
        self.out("")

        if self.backing_store:
            byte_width = len(color_streams[0])
            self.asm("jsr savebg_%dx%d" % (byte_width, self.height))
            self.backing_store_sizes.add((byte_width, self.height))
            cycle_count += 6
        
        cycle_count, optimization_count = self.generate_blitter(color_streams, mask_streams, cycle_count, baselabel)

        if not self.clobber:
            if self.processor == "any":
                self.out(".ifpC02")
                self.restore_axy_65C02()
                self.out(".else")
                self.restore_axy_6502()
                self.out(".endif")
            elif self.processor == "65C02":
                self.restore_axy_65C02()
            elif self.processor == "6502":
                self.restore_axy_6502()
            else:
                raise RuntimeError("Processor %s not supported" % self.processor)
        if self.damage:
            # the caller knows param_x and param_y for location, so no need
            # to report those again. But the size varies by sprite (and perhaps
            # by shift amount?) so store it here
            byte_width = len(color_streams[0])
            self.asm("lda #%d" % byte_width)
            self.asm("sta DAMAGE_W")
            self.asm("lda #%d" % self.height)
            self.asm("sta DAMAGE_H")
        self.out()
        self.asm("rts")
        self.comment("Cycle count: %d, Optimized %d rows." % (cycle_count,optimization_count))

    def generate_blitter(self, color_streams, mask_streams, base_cycle_count, baselabel):
        byte_width = len(color_streams[0])
        
        cycle_count = base_cycle_count
        optimization_count = 0

        order = list(range(self.height))

        for row in order:
            cycle_count += self.row_start_calculator_code(row, baselabel)

            byte_splits = color_streams[row]
            mask_splits = mask_streams[row]
            byte_count = len(byte_splits)

            # number of trailing iny to remove due to unchanged bytes at the
            # end of the row
            skip_iny = 0

            # Generate blitting code
            for index, (value, mask) in enumerate(zip(byte_splits, mask_splits)):
                if index > 0:
                    self.asm("iny")
                    cycle_count += 2

                # Optimization
                if mask == "01111111":
                    optimization_count += 1
                    self.comment_line("byte %d: skipping! unchanged byte (mask = %s)" % (index, mask))
                    skip_iny += 1
                else:
                    value = self.binary_constant(value)
                    skip_iny = 0
                    # Store byte into video memory
                    if self.xdraw:
                        self.asm("lda (scratch_addr),y")
                        self.asm("eor %s" % value)
                        self.asm("sta (scratch_addr),y");
                        cycle_count += 5 + 2 + 6
                    elif self.use_mask:
                        if mask == "00000000":
                            # replacing all the bytes; no need for and/or!
                            self.asm("lda %s" % value)
                            self.asm("sta (scratch_addr),y");
                            cycle_count += 2 + 5
                        else:
                            mask = self.binary_constant(mask)
                            self.asm("lda (scratch_addr),y")
                            self.asm("and %s" % mask)
                            self.asm("ora %s" % value)
                            self.asm("sta (scratch_addr),y");
                            cycle_count += 5 + 2 + 2 + 6
                    else:
                        self.asm("lda %s" % value)
                        self.asm("sta (scratch_addr),y");
                        cycle_count += 2 + 6

            while skip_iny > 0:
                self.pop_asm("iny")
                skip_iny -= 1
                cycle_count -= 2

        return cycle_count, optimization_count

    def row_start_calculator_code(self, row, baselabel):
        self.out()
        self.comment_line("row %d" % row)
        if row == 0:
            self.asm("ldx param_y")
            cycles = 3
        else:
            cycles = 0
        self.asm("lda HGRROWS_H1+%d,x" % row)
        cycles += 4
        if self.double_buffer:
            # HGRSELECT must be set to $00 or $60. The eor then turns the high
            # byte of page 1 into either page1 or page 2 by flipping the 5th
            # and 6th bit
            self.asm("eor HGRSELECT")
            cycles += 3
        self.asm("sta scratch_addr+1")
        self.asm("lda HGRROWS_L+%d,x" % row)
        self.asm("sta scratch_addr")
        cycles += 3 + 4 + 3
        if row == 0:
            self.asm("ldy param_x")
            self.asm("lda DIV%d_%d,y" % (self.screen.num_shifts, self.screen.bits_per_pixel))
            self.asm("sta scratch_col")  # save the mod lookup; it doesn't change
            self.asm("tay")
            cycles += 3 + 4 + 3 + 2
        else:
            self.asm("ldy scratch_col")
            cycles += 2
        return cycles;


def shift_string_right(string, shift, bits_per_pixel, filler_bit):
    if shift==0:
        return string
    
    shift *= bits_per_pixel
    result = ""
    
    for i in range(shift):
        result += filler_bit
        
    result += string
    return result
                


class ScreenFormat(object):
    num_shifts = 8

    bits_per_pixel = 1

    screen_width = 320

    screen_height = 192

    def __init__(self):
        self.offsets = self.generate_row_offsets()
        self.numX = self.screen_width // self.bits_per_pixel

    def byte_width(self, png_width):
        return (png_width * self.bits_per_pixel + self.num_shifts - 1) // self.num_shifts + 1

    def bits_for_color(self, pixel):
        raise NotImplementedError

    def bits_for_mask(self, pixel):
        raise NotImplementedError

    def pixel_color(self, pixel_data, row, col):
        raise NotImplementedError

    def generate_row_offsets(self):
        offsets = [40 * y for y in range(self.screen_height)]
        return offsets

    def generate_row_addresses(self, base_addr):
        addrs = [base_addr + offset for offset in self.offsets]
        return addrs


class HGR(ScreenFormat):
    num_shifts = 7

    bits_per_pixel = 2

    screen_width = 280

    black,magenta,green,orange,blue,white,key = list(range(7))

    def bits_for_color(self, pixel):
        if pixel == self.black or pixel == self.key:
            return "00"
        else:
            if pixel == self.white:
                return "11"
            else:
                if pixel == self.green or pixel == self.orange:
                    return "01"

        # blue or magenta
        return "10"

    def bits_for_mask(self, pixel):
        if pixel == self.key:
            return "11"

        return "00"

    def bits_for_bw(self, pixel, pixel_index=0):
        # if pixel == self.green or pixel == self.orange:
        #     pair = "01"
        # elif pixel == self.blue or pixel == self.magenta:
        #     pair = "10"
        # elif pixel == self.white:
        if pixel == self.white:
            return "1"
        else:
            return "0"
        return pair[pixel_index & 1]

    def bits_for_bw_mask(self, pixel):
        if pixel == self.key:
            return "1"
        return "0"

    def high_bit_for_color(self, pixel):
        # Note that we prefer high-bit white because blue fringe is less noticeable than magenta.
        high_bit = "0"
        if pixel == self.orange or pixel == self.blue or pixel == self.white:
            high_bit = "1"

        return high_bit

    def high_bit_for_mask(self, pixel):
        return "0"

    def get_rgb(self, pixel_data, row, col):
        r = pixel_data[row][col*3]
        g = pixel_data[row][col*3+1]
        b = pixel_data[row][col*3+2]
        return r, g, b

    def pixel_color(self, pixel_data, row, col):
        r, g, b = self.get_rgb(pixel_data, row, col)

        rhi = r == 255
        rlo = r == 0
        ghi = g == 255
        glo = g == 0
        bhi = b == 255
        blo = b == 0

        if rhi and ghi and bhi:
            color = self.white
        elif rlo and glo and blo:
            color = self.black
        elif rhi and bhi:
            color = self.magenta
        elif rhi and g > 0:
            color = self.orange
        elif bhi:
            color = self.blue
        elif ghi:
            color = self.green
        else:
            # anything else is chroma key
            color = self.key
        return color

    def byte_streams_from_pixels(self, shift, source, mask=False):
        byte_streams = ["" for x in range(source.height)]
        byte_width = self.byte_width(source.width)

        if mask:
            bit_delegate = self.bits_for_mask
            high_bit_delegate = self.high_bit_for_mask
            filler_bit = "1"
        else:
            bit_delegate = self.bits_for_color
            high_bit_delegate = self.high_bit_for_color
            filler_bit = "0"

        for row in range(source.height):
            bit_stream = ""
            high_bit = "0"
            high_bit_found = False
            
            # Compute raw bitstream for row from PNG pixels
            for pixel_index in range(source.width):
                pixel = self.pixel_color(source.pixel_data,row,pixel_index)
                bit_stream += bit_delegate(pixel)

                # Determine palette bit from first non-black pixel on each row
                if not high_bit_found and pixel != self.black and pixel != self.key:
                    high_bit = high_bit_delegate(pixel)
                    high_bit_found = True
            
            # Shift bit stream as needed
            bit_stream = shift_string_right(bit_stream, shift, self.bits_per_pixel, filler_bit)
            bit_stream = bit_stream[:byte_width*8]
            
            # Split bitstream into bytes
            bit_pos = 0
            byte_splits = [0 for x in range(byte_width)]
            
            for byte_index in range(byte_width):
                remaining_bits = len(bit_stream) - bit_pos
                    
                bit_chunk = ""
                
                if remaining_bits < 0:
                    bit_chunk = filler_bit * 7
                else:   
                    if remaining_bits < 7:
                        bit_chunk = bit_stream[bit_pos:]
                        bit_chunk += filler_bit * (7-remaining_bits)
                    else:   
                        bit_chunk = bit_stream[bit_pos:bit_pos+7]
                
                bit_chunk = bit_chunk[::-1]
                
                byte_splits[byte_index] = high_bit + bit_chunk
                bit_pos += 7
                
                byte_streams[row] = byte_splits;

        return byte_streams

    def generate_row_offsets(self):
        offsets = []
        for y in range(self.screen_height):
            # From Apple Graphics and Arcade Game Design
            a = y // 64
            d = y - (64 * a)
            b = d // 8
            c = d - 8 * b
            offsets.append((1024 * c) + (128 * b) + (40 * a))
        return offsets


class HGRBW(HGR):
    bits_per_pixel = 1

    def bits_for_color(self, pixel):
        return self.bits_for_bw(pixel)

    def bits_for_mask(self, pixel):
        return self.bits_for_bw_mask(pixel)

    def pixel_color(self, pixel_data, row, col):
        r, g, b = self.get_rgb(pixel_data, row, col)
        color = self.black
        
        if abs(r - g) < 16 and abs(g - b) < 16 and r!=0 and r!=255:   # Any grayish color is chroma key
            color = self.key
        elif r>25 or g>25 or b>25:  # pretty much all other colors are white
            color = self.white
        else:
            color = self.black
        return color


class RowLookup(Listing):
    def __init__(self, assembler, screen):
        Listing.__init__(self, assembler)
        self.slug = "hgrrows"
        if assembler.use_16_bit:
            self.generate_raw(screen)
        else:
            self.generate_y(screen)

    def generate_raw(self, screen):
        self.label("lines_page1")
        for addr in screen.generate_row_addresses(0x2000):
            self.word("0x%04x" % addr, 8)

        self.out("\n")
        self.label("lines_page2")
        for addr in screen.generate_row_addresses(0x4000):
            self.word("0x%04x" % addr, 8)

    def generate_y(self, screen):
        self.label("HGRROWS_H1")
        for addr in screen.generate_row_addresses(0x2000):
            self.byte("$%02x" % (addr // 256), 8)

        self.out("\n")
        self.label("HGRROWS_H2")
        for addr in screen.generate_row_addresses(0x4000):
            self.byte("$%02x" % (addr // 256), 8)

        self.out("\n")
        self.label("HGRROWS_L")
        for addr in screen.generate_row_addresses(0x2000):
            self.byte("$%02x" % (addr & 0xff), 8)


class ColLookup(Listing):
    def __init__(self, assembler, screen):
        Listing.__init__(self, assembler)
        self.slug = "hgrcols-%dx%d" % (screen.num_shifts, screen.bits_per_pixel)
        self.generate_x(screen)

    def generate_x(self, screen):
        self.out("\n")
        self.label("DIV%d_%d" % (screen.num_shifts, screen.bits_per_pixel))
        for pixel in range(screen.numX):
            self.byte("$%02x" % ((pixel * screen.bits_per_pixel) // screen.num_shifts), screen.num_shifts)

        self.out("\n")
        self.label("MOD%d_%d" % (screen.num_shifts, screen.bits_per_pixel))
        for pixel in range(screen.numX):
            # This is the index into the jump table, so it's always multiplied
            # by 2
            self.byte("$%02x" % ((pixel % screen.num_shifts) * 2), screen.num_shifts)


class BackingStore(Listing):
    # Each entry in the stack includes:
    # 2 bytes: address of restore routine
    # 1 byte: x coordinate
    # 1 byte: y coordinate
    # nn: x * y bytes of data, in lists of rows

    def __init__(self, assembler, byte_width, row_height):
        Listing.__init__(self, assembler)
        self.byte_width = byte_width
        self.row_height = row_height
        self.save_label = "savebg_%dx%d" % (byte_width, row_height)
        self.restore_label = "restorebg_%dx%d" % (byte_width, row_height)
        self.space_needed = self.compute_size()
        self.create_save()
        self.out()
        self.create_restore()
        self.out()

    def compute_size(self):
        return 2 + 1 + 1 + (self.byte_width * self.row_height)

    def create_save(self):
        self.label(self.save_label)

        # reserve space in the backing store stack
        self.asm("sec")
        self.asm("lda bgstore")
        self.asm("sbc #%d" % self.space_needed)
        self.asm("sta bgstore")
        self.asm("lda bgstore+1")
        self.asm("sbc #0")
        self.asm("sta bgstore+1")

        # save the metadata
        self.asm("ldy #0")
        self.asm("lda #<%s" % self.restore_label)
        self.asm("sta (bgstore),y")
        self.asm("iny")
        self.asm("lda #>%s" % self.restore_label)
        self.asm("sta (bgstore),y")
        self.asm("iny")
        self.asm("lda param_x")
        self.asm("sta (bgstore),y")
        self.asm("iny")
        self.asm("lda param_y")

        # Note that we can't clobber param_y like the restore routine can
        # because this is called in the sprite drawing routine and these
        # values must be retained to draw the sprite in the right place!
        self.asm("sta scratch_addr")
        self.asm("sta (bgstore),y")
        self.asm("iny")

        # The unrolled code is taken from Quinn's row sweep backing store
        # code in a previous version of HiSprite

        loop_label, col_label = self.smc_row_col(self.save_label, "scratch_addr")

        for c in range(self.byte_width):
            self.label(col_label % c)
            self.asm("lda $2000,x")
            self.asm("sta (bgstore),y")
            self.asm("iny")
            if c < self.byte_width - 1:
                # last loop doesn't need this
                self.asm("inx")

        self.asm("inc scratch_addr")

        self.asm("cpy #%d" % self.space_needed)
        self.asm("bcc %s" % loop_label)

        self.asm("rts")

    def smc_row_col(self, label, row_var):
        # set up smc for hires column, because the starting column doesn't
        # change when moving to the next row
        self.asm("ldx param_x")
        self.asm("lda DIV7_1,x")
        smc_label = "%s_smc1" % label
        self.asm("sta %s+1" % smc_label)

        loop_label = "%s_line" % label
        # save a line, starting from the topmost and working down
        self.label(loop_label)
        self.asm("ldx %s" % row_var)

        self.asm("lda HGRROWS_H1,x")
        col_label = "%s_col%%s" % label
        for c in range(self.byte_width):
            self.asm("sta %s+2" % (col_label % c))
        self.asm("lda HGRROWS_L,x")
        for c in range(self.byte_width):
            self.asm("sta %s+1" % (col_label % c))

        self.label(smc_label)
        self.asm("ldx #$ff")
        return loop_label, col_label

    def create_restore(self):
        # bgstore will be pointing right to the data to be blitted back to the
        # screen, which is 4 bytes into the bgstore array. Everything before
        # the data will have already been pulled off by the driver in order to
        # figure out which restore routine to call.  Y will be 4 upon entry,
        # and param_x and param_y will be filled with the x & y values.
        #
        # also, no need to save registers because this is being called from a
        # driver that will do all of that.
        self.label(self.restore_label)

        # we can clobber the heck out of param_y because we're being called from
        # the restore driver and when we return we are just going to load it up
        # with the next value anyway.
        loop_label, col_label = self.smc_row_col(self.restore_label, "param_y")

        for c in range(self.byte_width):
            self.asm("lda (bgstore),y")
            self.label(col_label % c)
            self.asm("sta $2000,x")
            self.asm("iny")
            if c < self.byte_width - 1:
                # last loop doesn't need this
                self.asm("inx")

        self.asm("inc param_y")
        self.asm("cpy #%d" % self.space_needed)
        self.asm("bcc %s" % loop_label)

        self.asm("rts")


class BackingStoreDriver(Listing):
    # Driver to restore the screen using all the saved data.
    # The backing store is a stack that grows downward in order to restore the
    # chunks in reverse order that they were saved.
    #
    # variables used:
    #   bgstore: (lo byte, hi byte) 1 + the first byte of free memory.
    #            I.e. points just beyond the last byte
    #   param_x: (byte) x coord
    #   param_y: (byte) y coord
    #
    # everything else is known because the sizes of each erase/restore
    # routine are hardcoded because this is a sprite *compiler*.
    #
    # Note that sprites of different sizes will have different sized entries in
    # the stack, so the entire list has to be processed in order. But you want
    # that anyway, so it's not a big deal.
    #
    # The global variable 'bgstore' is used as the stack pointer. It must be
    # initialized to a page boundary, the stack grows downward from there.
    # starting from the last byte on the previous page. E.g. if the initial
    # value is $c000, the stack grows down using $bfff as the highest address,
    # the initial bgstore value must point to 1 + the last usable byte
    #
    # All registers are clobbered because there's no real need to save them
    # since this will be called from the main game loop.

    def __init__(self, assembler, sizes):
        Listing.__init__(self, assembler)
        self.slug = "backing-store"
        self.add_driver()
        for byte_width, row_height in sizes:
            code = BackingStore(assembler, byte_width, row_height)
            self.add_listing(code)

    def add_driver(self):
        # Initialization routine needs to be called once at the beginning
        # of the program so that the savebg_* functions will have a valid
        # bgstore
        self.label("restorebg_init")
        self.asm("lda #0")
        self.asm("sta bgstore")
        self.asm("lda #BGTOP")
        self.asm("sta bgstore+1")
        self.asm("rts")
        self.out()

        # Driver routine to loop through the bgstore stack and copy the
        # data back to the screen
        self.label("restorebg_driver")
        self.asm("ldy #0")
        self.asm("lda (bgstore),y")
        self.asm("sta restorebg_jsr_smc+1")
        self.asm("iny")
        self.asm("lda (bgstore),y")
        self.asm("sta restorebg_jsr_smc+2")
        self.asm("iny")
        self.asm("lda (bgstore),y")
        self.asm("sta param_x")
        self.asm("iny ")
        self.asm("lda (bgstore),y")
        self.asm("sta param_y")
        self.asm("iny")
        self.label("restorebg_jsr_smc")
        self.asm("jsr $ffff")

        self.asm("clc")
        self.asm("tya")  # y contains the number of bytes processed
        self.asm("adc bgstore")
        self.asm("sta bgstore")
        self.asm("lda bgstore+1")
        self.asm("adc #0")
        self.asm("sta bgstore+1")
        self.asm("cmp #BGTOP")
        self.asm("bcc restorebg_driver")
        self.asm("rts")
        self.out()


class FastFont(Listing):
    def __init__(self, assembler, screen, font, double_buffer, byte_width=1, byte_height=8):
        Listing.__init__(self, assembler)
        self.slug = "fastfont"
        self.row_slug = "TransposedFontRow"
        self.generate_table(screen, "H1", 0x2000, byte_width, byte_height)
        if double_buffer:
            self.generate_table(screen, "H2", 0x4000, byte_width, byte_height)
        self.generate_transposed_font(screen, font, byte_width, byte_height)

    def generate_table(self, screen, suffix, hgrbase, byte_width, byte_height):
        label = "FASTFONT_%s" % suffix
        self.label(label)

        # Have to use self-modifying code because assembler may not allow
        # taking the hi/lo bytes of an address - 1
        self.comment("A = character, X = column, Y = row; A is clobbered, X&Y are not")
        self.asm("pha")
        self.asm(f"lda {label}_JMP_HI,y")
        self.asm(f"sta {label}_JMP+2")
        self.asm(f"lda {label}_JMP_LO,y")
        self.asm(f"sta {label}_JMP+1")
        self.asm("sty scratch_0")
        self.asm("pla")
        self.asm("tay")
        self.label(f"{label}_JMP")
        self.asm("jmp $ffff\n")

        num_rows = screen.screen_height // byte_height

        # Bit-shift jump table for generic 6502
        self.out()
        self.label(f"{label}_JMP_HI")
        for r in range(num_rows):
            self.asm(f".byte >{label}_{r}")
        self.label(f"{label}_JMP_LO")
        for r in range(num_rows):
            self.asm(f".byte <{label}_{r}")

        self.out()
        hgr1 = screen.generate_row_addresses(hgrbase)
        for r in range(num_rows):
            self.label(f"{label}_{r}")
            for b in range(byte_width):
                for h in range(byte_height):
                    self.asm(f"lda {self.row_slug}{b}_{h},y")
                    self.asm("sta $%04x,x" % (hgr1[r*byte_height + h] + b))
            self.asm("ldy scratch_0")
            self.asm("rts")
        self.out()

    def generate_transposed_font(self, screen, font, byte_width, byte_height):
        with open(font, 'rb') as fh:
            data = fh.read()
        num_bytes = len(data)
        char_size = byte_height * byte_width
        num_chars = num_bytes // char_size
        for h in range(byte_height):
            for b in range(byte_width):
                self.label(f"{self.row_slug}{b}_{h}")
                for i in range(num_chars):
                    index = i * char_size + (h * byte_width + b)
                    self.byte("$%02x" % data[index], 16)


class CompiledFastFont(Listing):
    def __init__(self, assembler, screen, font, double_buffer):
        Listing.__init__(self, assembler)
        self.slug = "compiledfont"
        with open(font, 'rb') as fh:
            self.font_data = fh.read()
        self.num_chars = len(self.font_data) // 8
        self.generate_table(screen, "H1", 0x2000)
        if double_buffer:
            self.generate_table(screen, "H2", 0x4000)

    def generate_table(self, screen, suffix, hgrbase):
        label = "COMPILEDFONT_%s" % suffix
        self.label(label)

        # Have to use self-modifying code because assembler may not allow
        # taking the hi/lo bytes of an address - 1
        self.comment("A = character, X = column, Y = row; A is clobbered, X&Y are not")
        self.asm("sty scratch_0")
        self.asm("tay")
        self.asm("lda %s_JMP_HI,y" % label)
        self.asm("sta %s_JMP+2" % label)
        self.asm("lda %s_JMP_LO,y" % label)
        self.asm("sta %s_JMP+1" % label)
        self.asm("ldy scratch_0")
        self.asm("lda hgrtextrow_l,y")
        self.asm("sta hgr_ptr")
        self.asm("lda hgrtextrow_h,y")
        self.asm("sta hgr_ptr+1")
        self.asm("txa")
        self.asm("tay")
        self.label("%s_JMP" % label)
        self.asm("jmp $ffff\n")

        # Bit-shift jump table for generic 6502
        self.out()
        self.label("%s_JMP_HI" % label)
        for r in range(self.num_chars):
            self.asm(".byte >%s_%d" % (label, r))
        self.label("%s_JMP_LO" % label)
        for r in range(self.num_chars):
            self.asm(".byte <%s_%d" % (label, r))

        self.out()
        index = 0
        for r in range(self.num_chars):
            self.label("%s_%d" % (label, r))
            for i in range(8):
                self.asm("lda #$%02x" % self.font_data[index])
                self.asm("sta (hgr_ptr),y")
                self.asm("clc")
                self.asm("lda #4")
                self.asm("adc hgr_ptr+1")
                self.asm("sta hgr_ptr+1")
                index += 1
            self.asm("ldy scratch_0")
            self.asm("rts")
        self.out()


class HGRByLine(HGR):
    """Either a color line or a BW line, depending on the contents of each
    line.

    If the entire line has only BW pixels, look at all the pixel data to
    preserve all 280 pixels across.

    Otherwise, look at every other pixel and convert as the normal HGR
    """
    bits_per_pixel = 1

    def __init__(self, color="line"):
        HGR.__init__(self)
        if color == "color":
            self.scan_line = self.scan_line_color
        elif color == "bw":
            self.scan_line = self.scan_line_bw
        else:
            self.scan_line = self.scan_line_default

    def is_pixel_on(self, pixel_data, row, col):
        r, g, b = self.get_rgb(pixel_data, row, col)
        # any pixel that is not super dark is considered on
        return r>25 or g>25 or b>25

    def scan_line_default(self, pixel_data, row, width):
        color_count = 0
        bw_count = 0
        for col in range(1, width):
            current = self.pixel_color(pixel_data, row, col)
            if current == self.white:
                bw_count += 1
            elif current != self.black and current != self.key:
                color_count += 1
        # print("row: %d, bw=%d, color=%d" % (row, bw_count, color_count))
        if color_count > 1:
            return self.color_processor
        return self.bw_processor

    def scan_line_color(self, pixel_data, row, width):
        return self.color_processor

    def scan_line_bw(self, pixel_data, row, width):
        return self.bw_processor

    def color_processor(self, pixel_data, row, width):
        bit_stream = ""
        high_bits = ""
        # Compute raw bitstream for row from PNG pixels, skipping every other
        # for color rendering
        for byte_index in range(0, width, 2*7):
            h = None
            # take high bit for each byte using the first non-black pixel
            for bit_index in range(0, 2*7, 2):
                pixel_index = byte_index + bit_index
                pixel = self.pixel_color(pixel_data,row,pixel_index)
                if h is None and pixel != self.black and pixel != self.key:
                    h = self.high_bit_for_color(pixel)
                bit_stream += self.bits_for_color(pixel)
            if h is None:
                h = "0"
            high_bits += h * 2*7
        
        return self.split_bit_stream(width, bit_stream, high_bits)

    def bw_processor(self, pixel_data, row, width):
        bit_stream = ""
        high_bits = ""
        # Compute raw bitstream for row from PNG pixels, skipping every other
        # for color rendering
        for pixel_index in range(0, width):
            pixel = self.pixel_color(pixel_data,row,pixel_index)
            bit_stream += self.bits_for_bw(pixel, pixel_index)
            h = self.high_bit_for_color(pixel)
            high_bits += h

        return self.split_bit_stream(width, bit_stream, high_bits)

    def split_bit_stream(self, width, bit_stream, high_bits):
        # print bit_stream
        # print high_bits

        # Split bitstream into bytes
        byte_width = width // 7
        bit_pos = 0
        filler_bit = "0"
        byte_splits = np.zeros((byte_width), dtype=np.uint8)

        for byte_index in range(byte_width):
            remaining_bits = len(bit_stream) - bit_pos
                
            bit_chunk = ""
            
            if remaining_bits < 0:
                bit_chunk = filler_bit * 7
            else:   
                if remaining_bits < 7:
                    bit_chunk = bit_stream[bit_pos:]
                    bit_chunk += filler_bit * (7-remaining_bits)
                else:   
                    bit_chunk = bit_stream[bit_pos:bit_pos+7]
            
            bit_chunk = bit_chunk[::-1]
            byte = high_bits[bit_pos] + bit_chunk
            #print("%d: %s" % (byte_index, byte))
            byte_splits[byte_index] = int(byte, 2)
            bit_pos += 7
        
        return byte_splits

    def lines_from_pixels(self, source):
        lines = np.zeros((192, 40), dtype=np.uint8)

        bit_delegate = self.bits_for_color
        high_bit_delegate = self.high_bit_for_color
        filler_bit = "0"

        for row in range(source.height):
            processor = self.scan_line(source.pixel_data, row, source.width)
            lines[row] = processor(source.pixel_data, row, source.width)

        return lines


class Image(object):
    def __init__(self, pngdata, fileroot, color):
        self.screen = HGRByLine(color)

        self.width = pngdata[0]
        self.height = pngdata[1]
        self.pixel_data = list(pngdata[2])
        self.lines = self.convert(fileroot)
        self.save(fileroot)

    def convert(self, fileroot):
        lines = self.screen.lines_from_pixels(self)
        output = "%s.hgr.png" % fileroot
        with open(output, "wb") as fh:
            # output PNG
            w = png.Writer(280, 192, greyscale=True, bitdepth=1)
            bits = np.fliplr(np.unpackbits(lines.ravel()).reshape(-1,8)[:,1:8])
            bw = bits.reshape((192, 280))
            w.write(fh, bw)
            print(f"created bw representation of HGR screen: {output}")
        return lines

    def save(self, fileroot, other=None, merge=96):
        offsets = self.screen.generate_row_addresses(0)
        # print ["%04x" % i for i in offsets]
        screen = np.zeros(8192, dtype=np.uint8)
        lines = self.lines
        for row in range(192):
            if other is not None and row == merge:
                lines = other.lines
            offset = offsets[row]
            screen[offset:offset+40] = lines[row]

        output = "%s.hgr" % fileroot
        with open(output, "wb") as fh:
            fh.write(screen)
            print(f"created HGR screen: {output}")


class RawHGRImage(object):
    def __init__(self, pathname):
        self.screen = HGR()
        self.raw = np.fromfile(pathname, dtype=np.uint8)
        if len(self.raw) != 8192:
            raise RuntimeError("Not HGR image size")

    def merge(self, other, merge_list):
        offsets = self.screen.generate_row_addresses(0)
        # print ["%04x" % i for i in offsets]
        screen = np.zeros(8192, dtype=np.uint8)
        raw = self.raw
        others = [1,0,1,0,1,0,1,0]
        choices = [raw, other.raw]
        print(others)
        merge = merge_list.pop(0)
        for row in range(192):
            if row == merge:
                # switch!
                i = others.pop(0)
                raw = choices[i]
                try:
                    merge = merge_list.pop(0)
                except IndexError:
                    merge = -1
            offset = offsets[row]
            screen[offset:offset+40] = raw[offset:offset+40]
        self.raw[:] = screen

    def save(self, fileroot):
        output = "%s.hgr" % fileroot
        with open(output, "wb") as fh:
            fh.write(self.raw)
            print(f"created HGR screen:{output}")


class FastScroll(Listing):
    def __init__(self, assembler, screen, lines=1, screen1=0x4000, screen2=0x2000):
        Listing.__init__(self, assembler)
        self.slug = "fastscroll"
        self.generate_table(screen, lines, screen1, screen2)

    def generate_table(self, screen, lines, source, dest):
        label = "FASTSCROLL_%x_%x" % (source, dest)
        end_label = "%s_RTS" % label
        outer_label = "%s_OUTER" % label
        inner_label = "%s_INNER" % label
        cont_label = "%s_NEXT_OUTER" % label
        self.label(end_label)
        self.asm("rts")
        self.label(label)

        smc_labels = []

        # Have to use self-modifying code because assembler may not allow
        # taking the hi/lo bytes of an address - 1
        self.comment("A,X,Y clobbered")
        self.asm("ldy #0")
        self.label(outer_label)
        self.asm("cpy #192")
        self.asm("bcs %s" % end_label)
        for r in range(lines):
            smc_labels.append("%s_SMC%d" % (label, r))
            self.asm("lda HGRROWS_L,y")
            self.asm("sta %s+1" % smc_labels[r])
            self.asm("lda HGRROWS_H2,y")
            self.asm("sta %s+2" % smc_labels[r])
            self.asm("iny")
        self.asm("ldx #39")
        self.label(inner_label)

        s = screen.generate_row_addresses(source)
        d = screen.generate_row_addresses(dest)
        for r in range(screen.screen_height - lines):
            self.asm("lda $%04x,x" % d[r + lines])
            self.asm("sta $%04x,x" % d[r])
        source = screen.screen_height - lines
        for r in range(lines):
            self.label(smc_labels[r])
            self.asm("lda $ffff,x")
            self.asm("sta $%04x,x" % d[r + screen.screen_height - lines])
        self.asm("dex")
        self.asm("bmi %s\n" % cont_label)
        self.asm("jmp %s" % inner_label)
        self.label(cont_label)
        self.asm("jmp %s" % outer_label)
        self.out()


class FastClear(Listing):
    def __init__(self, assembler, screen):
        Listing.__init__(self, assembler)
        self.slug = "fastclear"
        self.generate_table(screen, 0)

    def generate_table(self, screen, offset):
        base = 0x2000 + offset
        label = "FASTCLEAR_%x" % (base)
        end_label = "%s_RTS" % label
        inner_label = "%s_INNER" % label
        self.label(label)

        smc_labels = []

        # Have to use self-modifying code because assembler may not allow
        # taking the hi/lo bytes of an address - 1
        self.comment("A,X clobbered")
        self.asm("lda #$aa")
        self.asm("ldx #39")
        self.label(inner_label)

        s = screen.generate_row_addresses(base)
        for r in range(screen.screen_height):
            self.asm("sta $%04x,x" % s[r])
        self.asm("dex")
        self.asm("bmi %s\n" % end_label)
        self.asm("jmp %s" % inner_label)
        self.label(end_label)
        self.asm("rts")
        self.out()


class InsaneClear(Listing):
    def __init__(self, assembler, screen):
        Listing.__init__(self, assembler)
        self.slug = "insaneclear"
        self.generate_table(screen, 0)

    def generate_table(self, screen, offset):
        base = 0x2000 + offset
        label = "INSANECLEAR_%x" % (base)
        self.label(label)
        self.comment("A clobbered")
        self.asm("lda #$aa")

        s = screen.generate_row_addresses(base)
        for c in range(40):
            for r in range(screen.screen_height):
                self.asm("sta $%04x" % (s[r] + c))
        self.asm("rts")
        self.out()


class RLE(Listing):
    def __init__(self, assembler, data):
        Listing.__init__(self, assembler)
        self.raw = np.asarray(data, dtype=np.uint8)
        rle = self.calc_rle()
        #c1 = self.compress_pcx(rle)
        #c2 = self.compress_high_bit_swap(rle)
        c3 = self.compress_run_copy(rle)

    def calc_rle(self):
        """ run length encoding. Partial credit to R rle function. 
            Multi datatype arrays catered for including non Numpy
            returns: tuple (runlengths, startpositions, values) """
        ia = self.raw
        n = len(ia)
        if n == 0: 
            return ([], [], [])
        else:
            y = np.array(ia[1:] != ia[:-1])     # pairwise unequal (string safe)
            i = np.append(np.where(y), n - 1)   # must include last element posi
            z = np.diff(np.append(-1, i))       # run lengths
            p = np.cumsum(np.append(0, z))[:-1] # positions
            return(z, p, ia[i])

    def compress_pcx(self, rle):
        run_lengths, pos, values = rle

        # Max size will be the same size as the original data. If compressed is
        # greater than original, abort
        compressed = np.empty(len(self.raw), dtype=np.uint8)

        compressed_size = 0
        for i in range(len(run_lengths)):
            p, r, v = pos[i], run_lengths[i], values[i]
            if v < 0x80:
                num_tokens = 1
            else:
                num_tokens = 2
            print(f"{p}: run {r} of {v} ({num_tokens})")
            compressed_size += num_tokens
        print(f"compressed size: {compressed_size}")
        return compressed_size

    def compress_high_bit_swap(self, rle):
        run_lengths, pos, values = rle

        # Max size will be the same size as the original data. If compressed is
        # greater than original, abort
        compressed = np.empty(len(self.raw), dtype=np.uint8)

        compressed_size = 0
        high_bit_set = False
        for i in range(len(run_lengths)):
            p, r, v = pos[i], run_lengths[i], values[i]
            changed = high_bit_set
            if r == 1:
                if v < 0x80 and not high_bit_set:
                    num_tokens = 1
                elif v > 0x80 and high_bit_set:
                    num_tokens = 1
                elif v == 0x80:
                    num_tokens = 2
                else:
                    high_bit_set = not high_bit_set
                    num_tokens = 2
            else:
                num_tokens = 2
            high_bit_notice = "" if changed == high_bit_set else f" high bit = {high_bit_set}"
            print(f"{p}: run {r} of {v} ({num_tokens}){high_bit_notice}")
            compressed_size += num_tokens
        print(f"compressed size: {compressed_size}")
        return compressed_size

    def compress_run_copy(self, rle):
        run_lengths, pos, values = rle

        # Max size will be the same size as the original data. If compressed is
        # greater than original, abort
        compressed = np.empty(len(self.raw), dtype=np.uint8)

        compressed_size = 0
        copy_start = -1
        for i in range(len(run_lengths)):
            p, r, v = pos[i], run_lengths[i], values[i]
            if r < 3:
                if copy_start < 0:
                    copy_start = p
                elif copy_start - p + r > 127:
                    num = p - copy_start
                    compressed_size += num + 1
                    print(f"{copy_start}: copy {num} ({num + 1})")
                    copy_start = p
            else:
                if copy_start >= 0:
                    num = p - copy_start
                    compressed_size += num + 1
                    print(f"{copy_start}: copy {num} ({num + 1})")
                    copy_start = -1
                while r > 2:
                    num = min(r, 128)
                    print(f"{p}: run {num} of {v} (2)" % (p, num, v))
                    p += num
                    r -= num
                    compressed_size += 2
                if r > 0:
                    copy_start = p
        if copy_start >= 0:
            num = p - copy_start
            compressed_size += num + 1
            print(f"{copy_start}: copy {num} ({num + 1})")
        print(f"compressed size: {compressed_size}")
        return compressed_size


class RawToSource(Listing):
    def __init__(self, assembler, data, slug):
        Listing.__init__(self, assembler, slug)
        raw = np.asarray(data, dtype=np.uint8)
        self.generate_table(raw)

    def generate_table(self, raw):
        self.label("%s_START" % (self.slug))
        for i in range(len(raw)):
            self.byte(str(int(raw[i])), 16)
        self.label("%s_END" % (self.slug))
        self.comment("%d bytes" % len(raw))
        self.out()


if __name__ == "__main__":
    disclaimer = '''; AUTOGENERATED FILE; DO NOT EDIT!
;
; This file was generated by asmgen.py, a 6502 code generator sponsored by
; the Player/Missile Podcast. (The sprite compiler is based on HiSprite by
; Quinn Dunki).
;
; The code produced by asmgen is licensed under the Creative Commons
; Attribution 4.0 International (CC BY 4.0), so you are free to use the code in
; this file for any purpose. (The code generator itself is licensed under the
; GPLv3.)
'''

if __name__ == "__main__":
    additional = '''; param_x = $10  ; Default definition
; param_y = $10  ; Default definition
; scratch_addr = $6000
; scratch_col = $20
'''


    parser = argparse.ArgumentParser(description="Code generator for 65C02/6502 to generate assembly code for a number of tasks, including fast font rendering to the hi-res screen and sprite compiling. The sprite compiler will render all shifts of the given sprite, optionally with exclusive-or drawing (if background will be non-black). Generated code has conditional compilation directives for the CC65 assembler to allow the same file to be compiled for either architecture.")
    parser.add_argument("-v", "--verbose", default=0, action="count")
    parser.add_argument("-c", "--cols", action="store_true", default=False, help="output column (x position) lookup tables")
    parser.add_argument("-r", "--rows", action="store_true", default=False, help="output row (y position) lookup tables")
    parser.add_argument("-x", "--xdraw", action="store_true", default=False, help="use XOR for sprite drawing")
    parser.add_argument("-m", "--mask", action="store_true", default=False, help="use mask for sprite drawing")
    parser.add_argument("-b", "--backing-store", action="store_true", default=False, help="add code to store background")
    parser.add_argument("-a", "--assembler", default="cc65", choices=["cc65","mac65", "merlin", "c",], help="Assembler syntax (default: %(default)s)")
    parser.add_argument("-p", "--processor", default="any", choices=["any","6502", "65C02"], help="Processor type (default: %(default)s)")
    parser.add_argument("-s", "--screen", default="hgrcolor", choices=["hgrcolor","hgrbw"], help="Screen format (default: %(default)s)")
    parser.add_argument("-i", "--image", default="line", choices=["line", "color","bw"], help="Screen format used for full page image conversion (default: %(default)s)")
    parser.add_argument("-l", "--scroll", default=0, type=int, help="Unrolled loop to scroll screen (default: %(default)s)")
    parser.add_argument("--clear", action="store_true", default=False, help="Unrolled loop to clear screen (default: %(default)s)")
    parser.add_argument("--insane-clear", action="store_true", default=False, help="Unrolled loop to clear screen (default: %(default)s)")
    parser.add_argument("--merge", type=int, nargs="*", help="Merge two HGR images, switching images at the scan line")
    parser.add_argument("--rle", action="store_true", default=False, help="Create run-length-encoded version of data (assumed to be an image)")
    parser.add_argument("--src", action="store_true", default=False, help="Create source version of binary file")
    parser.add_argument("-n", "--name", default="", help="Name for generated assembly function (default: based on image filename)")
    parser.add_argument("-k", "--clobber", action="store_true", default=False, help="don't save the registers on the stack")
    parser.add_argument("-d", "--double-buffer", action="store_true", default=False, help="add code blit to either page (default: page 1 only)")
    parser.add_argument("-g", "--damage", action="store_true", default=False, help="add code to report size of sprite upon return. Can be used in a damage list to restore an area from a pristine source.")
    parser.add_argument("-f", "--font", action="store", default="", help="generate a fast font blitter for text on the hgr screen using the specified binary font file")
    parser.add_argument("--font-size", "--fs", action="store", default="1x8", help="specify font dimensions in bytes (default: %(default)s)")
    parser.add_argument("--compiled-font", action="store", default="", help="generate a font-compiled fairly fast font blitter for text on the hgr screen using the specified binary font file")
    parser.add_argument("-o", "--output-prefix", default="", help="Base name to create a set of output files. If not supplied, all code will be sent to stdout.")
    parser.add_argument("files", metavar="IMAGE", nargs="*", help="a PNG image [or a list of them]. PNG files must not have an alpha channel!")
    options, extra_args = parser.parse_known_args()

    if options.assembler.lower() == "cc65":
        assembler = CC65()
    elif options.assembler.lower() == "mac65":
        assembler = Mac65()
    elif options.assembler.lower() == "merlin":
        assembler = Merlin()
        if options.processor.lower() == "any":
            options.processor = "6502" # no processor conditional support.
    elif options.assembler.lower() == "c":
        assembler = CSource()
    else:
        print(f"Unknown assembler {options.assembler}")
        parser.print_help()
        sys.exit(1)

    if options.screen.lower() == "hgrcolor":
        screen = HGR()
    elif options.screen.lower() == "hgrbw":
        screen = HGRBW()
    else:
        print(f"Unknown screen format {options.screen}")
        parser.print_help()
        sys.exit(1)

    listings = []
    luts = {}  # dict of lookup tables to prevent duplication in output files

    if options.merge:
        if len(options.files) != 2:
            print("Merge requires exactly 2 HGR images")
            parser.print_help()
            sys.exit(1)
        print(options.merge)
        hgr1 = RawHGRImage(options.files[0])
        hgr2 = RawHGRImage(options.files[1])
        hgr1.merge(hgr2, options.merge)
        hgr1.save(options.output_prefix)
        sys.exit(0)

    for pngfile in options.files:
        name = options.name if options.name else os.path.splitext(pngfile)[0]
        slug = slugify(name)

        if pngfile.lower().endswith(".png"):
            try:
                reader = png.Reader(pngfile)
                pngdata = reader.asRGB8()
            except RuntimeError as e:
                print(f"{pngfile}: {e}")
                sys.exit(1)
            except png.Error as e:
                print(f"{pngfile}: {e}")
                sys.exit(1)

            w, h = pngdata[0:2]
            if w == 280 and h == 192:
                # Full screen conversion!
                Image(pngdata, name, options.image.lower())
            else:
                sprite_code = Sprite(slug, pngdata, assembler, screen, options.xdraw, options.mask, options.backing_store, options.clobber, options.double_buffer, options.damage, options.processor)
                listings.append(sprite_code)
                if options.output_prefix:
                    r = RowLookup(assembler, screen)
                    luts[r.slug] = r
                    c = ColLookup(assembler, screen)
                    luts[c.slug] = c
        else:
            data = np.fromfile(pngfile, dtype=np.uint8)
            if options.rle:
                listings.append(RLE(assembler, data))
            elif options.src:
                listings.append(RawToSource(assembler, data, slug))


    listings.extend([luts[k] for k in sorted(luts.keys())])

    if options.rows:
        listings.append(RowLookup(assembler, screen))

    if options.cols:
        listings.append(ColLookup(assembler, screen))

    if options.font_size:
        w, h = options.font_size.lower().split("x", 1)
        w = int(w)
        h = int(h)
    else:
        w = 1
        h = 8

    if options.font:
        listings.append(FastFont(assembler, screen, options.font, options.double_buffer, w, h))

    if options.compiled_font:
        listings.append(CompiledFastFont(assembler, screen, options.compiled_font, options.double_buffer))

    if options.scroll:
        listings.append(FastScroll(assembler, screen, options.scroll))

    if options.clear:
        listings.append(FastClear(assembler, screen))

    if options.insane_clear:
        listings.append(InsaneClear(assembler, screen))

    if listings:
        if options.output_prefix:
            if Sprite.backing_store_sizes:
                backing_store_code = BackingStoreDriver(assembler, Sprite.backing_store_sizes)
                listings.append(backing_store_code)
            driver = Listing(assembler)
            for source in listings:
                genfile = source.write(options.output_prefix, disclaimer)
                driver.include(genfile)
            driver.write(options.output_prefix, disclaimer + additional)
        else:
            print(disclaimer)

            for section in listings:
                print(section)
