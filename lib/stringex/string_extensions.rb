# encoding: UTF-8

module Stringex
  # These methods are all added on String class.
  module StringExtensions
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
    end

    # Returns the string converted (via Textile/RedCloth) to HTML format
    # or self [with a friendly warning] if Redcloth is not available.
    #
    # Using <tt>:lite</tt> argument will cause RedCloth to not wrap the HTML in a container
    # P element, which is useful behavior for generating header element text, etc.
    # This is roughly equivalent to ActionView's <tt>textilize_without_paragraph</tt>
    # except that it makes RedCloth do all the work instead of just gsubbing the return
    # from RedCloth.
    def to_html(lite_mode = false)
      if defined?(RedCloth)
        if lite_mode
          RedCloth.new(self, [:lite_mode]).to_html
        else
          if self =~ /<pre>/
            RedCloth.new(self).to_html.tr("\t", "")
          else
            RedCloth.new(self).to_html.tr("\t", "").gsub(/\n\n/, "")
          end
        end
      else
        warn "String#to_html was called without RedCloth being successfully required"
        self
      end
    end

    # Create a URI-friendly representation of the string. This is used internally by
    # acts_as_url[link:classes/Stringex/ActsAsUrl/ClassMethods.html#M000012]
    # but can be called manually in order to generate an URI-friendly version of any string.
    def to_url(options = {})
      remove_formatting(options).downcase.replace_whitespace("-").collapse("-").limit(options[:limit])
    end

    def limit(lim = nil)
      lim.nil? ? self : self[0...lim]
    end

    # Performs multiple text manipulations. Essentially a shortcut for typing them all. View source
    # below to see which methods are run.
    def remove_formatting(options = {})
      strip_html_tags.convert_smart_punctuation.convert_accented_entities.convert_vulgar_fractions.convert_misc_entities.to_ascii.convert_misc_characters(options).collapse
    end

    # Removes HTML tags from text. This code is simplified from Tobias Luettke's regular expression
    # in Typo[http://typosphere.org].
    def strip_html_tags(leave_whitespace = false)
      name = /[\w:_-]+/
      value = /([A-Za-z0-9]+|('[^']*?'|"[^"]*?"))/
      attr = /(#{name}(\s*=\s*#{value})?)/
      rx = /<[!\/?\[]?(#{name}|--)(\s+(#{attr}(\s+#{attr})*))?\s*([!\/?\]]+|--)?>/
      (leave_whitespace) ?  gsub(rx, "").strip : gsub(rx, "").gsub(/\s+/, " ").strip
    end

    # Converts HTML entities into the respective non-accented letters. Examples:
    #
    #   "&aacute;".convert_accented_entities # => "a"
    #   "&ccedil;".convert_accented_entities # => "c"
    #   "&egrave;".convert_accented_entities # => "e"
    #   "&icirc;".convert_accented_entities # => "i"
    #   "&oslash;".convert_accented_entities # => "o"
    #   "&uuml;".convert_accented_entities # => "u"
    #
    # Note: This does not do any conversion of Unicode/ASCII accented-characters. For that
    # functionality please use <tt>to_ascii</tt>.
    def convert_accented_entities
      gsub(/&([A-Za-z])(grave|acute|circ|tilde|uml|ring|cedil|slash);/, '\1').strip
    end

    # Converts HTML entities (taken from common Textile/RedCloth formattings) into plain text formats.
    #
    # Note: This isn't an attempt at complete conversion of HTML entities, just those most likely
    # to be generated by Textile.
    def convert_misc_entities
      dummy = dup
      {
        "#822[01]" => "\"",
        "#821[67]" => "'",
        "#8230" => "...",
        "#8211" => "-",
        "#8212" => "--",
        "#215" => "x",
        "gt" => ">",
        "lt" => "<",
        "(#8482|trade)" => "(tm)",
        "(#174|reg)" => "(r)",
        "(#169|copy)" => "(c)",
        "(#38|amp)" => "and",
        "nbsp" => " ",
        "(#162|cent)" => " cent",
        "(#163|pound)" => " pound",
        "(#188|frac14)" => "one fourth",
        "(#189|frac12)" => "half",
        "(#190|frac34)" => "three fourths",
        "(#176|deg)" => " degrees "
      }.each do |textiled, normal|
        dummy.gsub!(/&#{textiled};/, normal)
      end
      dummy.gsub(/&[^;]+;/, "").strip
    end

    # Converts vulgar fractions from supported html entities and unicode to
    # plain text formats.
    def convert_vulgar_fractions
      dummy = dup
      {
        "(&#188;|&frac14;|¼)" => "one fourth",
        "(&#189;|&frac12;|½)" => "half",
        "(&#190;|&frac34;|¾)" => "three fourths",
        "(&#8531;|⅓)" => "one third",
        "(&#8532;|⅔)" => "two thirds",
        "(&#8533;|⅕)" => "one fifth",
        "(&#8534;|⅖)" => "two fifths",
        "(&#8535;|⅗)" => "three fifths",
        "(&#8536;|⅘)" => "four fifths",
        "(&#8537;|⅙)" => "one sixth",
        "(&#8538;|⅚)" => "five sixths",
        "(&#8539;|⅛)" => "one eighth",
        "(&#8540;|⅜)" => "three eighths",
        "(&#8541;|⅝)" => "five eighths",
        "(&#8542;|⅞)" => "seven eighths"
      }.each do |textiled, normal|
        dummy.gsub!(/#{textiled}/, normal)
      end
      dummy
    end

    # Converts MS Word 'smart punctuation' to ASCII
    #
    def convert_smart_punctuation
      dummy = dup
      {

        "(“|”|\302\223|\302\224|\303\222|\303\223)" => '"',
        "(‘|’|\302\221|\302\222|\303\225)" => "'",
        "…" => "...",
      }.each do |smart, normal|
        dummy.gsub!(/#{smart}/, normal)
      end
      dummy.strip
    end

    # Converts various common plaintext characters to a more URI-friendly representation.
    # Examples:
    #
    #   "foo & bar".convert_misc_characters # => "foo and bar"
    #   "Chanel #9".convert_misc_characters # => "Chanel number nine"
    #   "user@host".convert_misc_characters # => "user at host"
    #   "google.com".convert_misc_characters # => "google dot com"
    #   "$10".convert_misc_characters # => "10 dollars"
    #   "*69".convert_misc_characters # => "star 69"
    #   "100%".convert_misc_characters # => "100 percent"
    #   "windows/mac/linux".convert_misc_characters # => "windows slash mac slash linux"
    #
    # Note: Because this method will convert any & symbols to the string "and",
    # you should run any methods which convert HTML entities (convert_html_entities and convert_misc_entities)
    # before running this method.
    def convert_misc_characters(options = {})
      dummy = dup.gsub(/\.{3,}/, " dot dot dot ") # Catch ellipses before single dot rule!
      # Special rules for money
      {
        /(\s|^)\$(\d+)\.(\d+)(\s|$)/ => '\2 dollars \3 cents',
        /(\s|^)£(\d+)\.(\d+)(\s|$)/u => '\2 pounds \3 pence',
      }.each do |found, replaced|
        replaced = " #{replaced} " unless replaced =~ /\\1/
        dummy.gsub!(found, replaced)
      end
      # Back to normal rules
      misc_characters =
      {
        /\s*&\s*/ => "and",
        /\s*#/ => "number",
        /\s*@\s*/ => "at",
        /(\S|^)\.(\S)/ => '\1 dot \2',
        /(\s|^)\$(\d*)(\s|$)/ => '\2 dollars',
        /(\s|^)£(\d*)(\s|$)/u => '\2 pounds',
        /(\s|^)¥(\d*)(\s|$)/u => '\2 yen',
        /\s*\*\s*/ => "star",
        /\s*%\s*/ => "percent",
        /(\s*=\s*)/ => " equals ",
        /\s*\+\s*/ => "plus",
        /\s*°\s*/ => "degrees"
      }
      misc_characters[/\s*(\\|\/|／)\s*/] = 'slash' unless options[:allow_slash]
      misc_characters.each do |found, replaced|
        replaced = " #{replaced} " unless replaced =~ /\\1/
        dummy.gsub!(found, replaced)
      end
      dummy = dummy.gsub(/(^|[[:alpha:]])'([[:alpha:]]|$)/, '\1\2').gsub(/[\.,:;()\[\]\/\?!\^'ʼ"_]/, " ").strip
    end

    # Replace runs of whitespace in string. Defaults to a single space but any replacement
    # string may be specified as an argument. Examples:
    #
    #   "Foo       bar".replace_whitespace # => "Foo bar"
    #   "Foo       bar".replace_whitespace("-") # => "Foo-bar"
    def replace_whitespace(replace = " ")
      gsub(/\s+/, replace)
    end

    # Removes specified character from the beginning and/or end of the string and then performs
    # <tt>String#squeeze(character)</tt>, condensing runs of the character within the string.
    #
    # Note: This method has been superceded by ActiveSupport's squish method.
    def collapse(character = " ")
      sub(/^#{character}*/, "").sub(/#{character}*$/, "").squeeze(character)
    end

    module ClassMethods
      # Returns string of random characters with a length matching the specified limit. Excludes 0
      # to avoid confusion between 0 and O.
      def random(limit)
        strong_alphanumerics = %w{
          a b c d e f g h i j k l m n o p q r s t u v w x y z
          A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
          1 2 3 4 5 6 7 8 9
        }
        Array.new(limit, "").collect{strong_alphanumerics[rand(61)]}.join
      end
    end
  end
end
