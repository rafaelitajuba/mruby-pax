class PAX
  class Printer
    RET_OK                = 0
    ERR_PRN_BUSY          = -3701 # Printer busy
    ERR_PRN_PAPEROUT      = -3702 # Out of paper
    ERR_PRN_WRONG_PACKAGE = -3703 # The format of print data packet error
    ERR_PRN_OVERHEAT      = -3704 # Printer over heating
    ERR_PRN_OUTOFMEMORY   = -3705 # The print data is too large, and exceeds the buffer length.
    ERR_PRN_OVERVOLTAGE   = -3706 # Voltage is too high.
    ERR_INVALID_PARAM     = -1003 # Invalid parameter.
    ERR_DEV_NOT_EXIST     = -1004 # Device does not exist.
    ERR_DEV_BUSY          = -1005 # Device is busy.
    ERR_FONT_NOT_EXIST    = -1008 # Font does not exist.

    DEFAULT_SINGLE_WIDTH  = 12
    DEFAULT_SINGLE_HEIGHT = 24
    DEFAULT_MULTI_WIDTH   = 24
    DEFAULT_MULTI_HEIGHT  = 24

    class << self
      attr_accessor :single_width, :single_height, :multi_width, :multi_height, :thread, :printer_control
    end

    def self.allow?
      System.model != "d200"
    end

    self.single_width  = DEFAULT_SINGLE_WIDTH
    self.single_height = DEFAULT_SINGLE_HEIGHT
    self.multi_width   = DEFAULT_MULTI_WIDTH
    self.multi_height  = DEFAULT_MULTI_HEIGHT

    # @brief Initialize Printer device.
    #
    # @param singlecode_width [Fixnum] The width control of single code font.
    #  (For non-monospaced font, width of each character may not meet the settings).
    #  The value ranges from 8 to 64.
    # @param singlecode_height [Fixnum] The height control of single code font.
    #  The value ranges from 8 to 64.
    # @param multicode_width [Fixnum] The width control of multiple code font.
    #  The value ranges from 12 to 64.
    # @param multicode_height [Fixnum] The height control of multiple code font
    #  The value ranges from 12 to 64.
    #
    # @retval RET_OK Success.
    # @retval ERR_FONT_NOT_EXIST Font does not exist.
    # @retval ERR_INVALID_PARAM Invalid parameter.
    # @retval ERR_DEV_BUSY Device is busy.
    #
    # @return [Fixnum] Return number.
    def self.start(singlecode_width=DEFAULT_SINGLE_WIDTH,
                   singlecode_height=DEFAULT_SINGLE_HEIGHT,
                   multicode_width=DEFAULT_MULTI_WIDTH,
                   multicode_height=DEFAULT_MULTI_HEIGHT)
      ret = self.open
      if ret == RET_OK
        self.single_width  = singlecode_width
        self.single_height = singlecode_height
        self.multi_width   = multicode_width
        self.multi_height  = multicode_height

        self.size(singlecode_width, singlecode_height, multicode_width, multicode_height)
      end
      ret
    end

    # @brief Start Printer Device.
    #
    # @retval RET_OK Success.
    # @retval ERR_FONT_NOT_EXIST Font does not exist.
    # @retval ERR_INVALID_PARAM Invalid parameter.
    # @retval ERR_DEV_BUSY Device is busy.
    #
    # @return [Fixnum] Return number.
    def self.open
      if self.allow?
        self._open
        self.thread_new
      end
    end

    def self.thread_new
      self.printer_control = PrinterControl.new
      self.thread = Thread.new(self.printer_control) do |printer|
        loop do
          break if printer.kill
          if printer.flag_print
            printer.flag_print = false
            timeout = Time.now + 4
            usleep 700_000
            loop do
              if ! printer.flag_print || timeout < Time.now
                break
              else
                printer.flag_print = false
                usleep 400_000
              end
            end
            printer.print
            PAX::Printer.font("AerialMono.ttf")
          end
          nil
        end
      end
    end

    def self.thread_print
      self.printer_control.flag_print = true
      unless self.thread.alive?
        thread_kill
        thread_new
      end
    end

    def self.thread_kill
      if self.thread
        self.printer_control.kill!
        self.thread.join
      end
    end

    # @brief Restore the printer default settings and clear the print buffer data.
    #
    # @return [NilClass] Allways returns nil.
    def self.reset
      self._reset if self.allow?
    end

    # @brief Closes the printer.
    #
    # @return [NilClass] Allways returns nil.
    def self.close
      self._close if self.allow?
    end

    # @brief Selects print font.
    #
    # @param filename [String] Font filename.
    #
    # @retval RET_OK Success.
    # @retval ERR_FONT_NOT_EXIST Font does not exist.
    # @retval ERR_INVALID_PARAM Invalid parameter.
    def self.font(filename)
      self._font(filename) if self.allow?
    end

    # @brief Sets printing gray level.
    #
    # @param value [Fixnum] Value to define level
    # 􏰀 Level =0, reserved,
    # 􏰀 Level =1, default level, normal print slip,
    # 􏰀 Level =2, reserved,
    # 􏰀 Level =3, two-layer thermal printing,
    # 􏰀 Level =4, two-layer thermal printing, higher gray
    # level than 3,
    # 􏰀 The default level is 1.
    # 􏰀 The illegal value does not change current settings.
    #
    # @return [NilClass] Allways returns nil.
    def self.level=(value)
      self._level = value if self.allow?
    end

    # @brief Define size, in pixel, of printing
    #
    # @param singlecode_width [Fixnum] The width control of single code font.
    # (For non-monospaced font, width of each character may not meet the settings).
    #  The value ranges from 8 to 64.
    # @param singlecode_height [Fixnum] The height control of single code font.
    #  The value ranges from 8 to 64.
    # @param multicode_width [Fixnum] The width control of multiple code font.
    #  The value ranges from 12 to 64.
    # @param multicode_height [Fixnum] The height control of multiple code font
    #  The value ranges from 12 to 64.
    #
    # @return [NilClass] Allways returns nil.
    def self.size(singlecode_width = self.single_width,
                  singlecode_height = self.single_height,
                  multicode_width   = self.multi_width,
                  multicode_height  = self.multi_height)

      if self.allow?
        if singlecode_width == 10
          self._size(9, 20, 12, 24)
        else
          self._size(singlecode_width, singlecode_height, multicode_width, multicode_height)
        end
      end
    end

    # @brief Feeds printing paper “pixel” pixels in print buffer.
    #
    # @param pixel [Fixnum] Number of pixels.
    #
    # @return [NilClass] Allways returns nil.
    def self.feed(pixels = 60)
      if self.allow?
        self._print("\f")
        thread_print
      end
    end

    # @brief Write text on print buffer.
    #
    # @param string [String] Text to be printed.
    #
    # @return [NilClass] Allways returns nil.
    def self.print(string)
      if self.allow? && ! string.to_s.empty?
        self._print("#{string}\n")
        self.thread_print
      end
    end

    # @brief Write text on print buffer.
    #
    # @param string [String] Text to be printed.
    #
    # @return [NilClass] Allways returns nil.
    def self.puts(string)
      self.print(string) if self.allow?
    end

    BMP_SUCCESS        = 0
    BMP_FILE_ERROR     = -1
    BMP_NOT_MONOCHROME = -3
    BMP_INVALID_WIDTH  = -4
    BMP_LSEEK_FAILED   = -5

    # @brief Print barcode as bmp image.
    #
    # TODO Scalone
    #
    # @param path [String] Path to bmp file.
    #
    # @return [Integer] 0 success -1 fail.
    def self.print_barcode(code)
      if self.allow?
        self._print_barcode(code)
        self.thread_print
      end
    end

    # @brief Print bmp file.
    #
    # Details:
    # Bitmap data is generated as monochromatic, bmp format.
    # Printing bitmap size limit up to 384 pixels in width, spocket with 180 pixels and the height is unlimited.
    # If the bitmap width is larger than the limit of the printer, then it will be sliced on the right side.
    # If the data packet is too long, then this function will remove the LOGO message.
    #
    # @param path [String] Path to bmp file.
    #
    # @return [Integer] 0 success -1 fail.
    def self.print_bmp(path)
      if self.allow?
        if File.exists?(path)
          self._print_bmp(path)
          thread_print
        else
          BMP_FILE_ERROR
        end
      end
    end

    # @brief Check printer status, useful for paper check.
    #
    # @retval RET_OK Success.
    # @retval ERR_FONT_NOT_EXIST Font does not exist.
    # @retval ERR_INVALID_PARAM Invalid parameter.
    # @retval ERR_PRN_BUSY Printer is busy.
    # @retval ERR_PRN_PAPEROUT Out of paper.
    # @retval ERR_PRN_OVERHEAT Printer overheating.
    def self.check
      self._check if self.allow?
    end
  end
end

