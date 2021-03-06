# encoding: UTF-8
#
# By Henrik Nyh <http://henrik.nyh.se> 2008-01-30.
# Free to modify and redistribute with credit.

# modified by Dave Nolan <http://textgoeshere.org.uk> 2008-02-06
# Ellipsis appended to text of last HTML node
# Ellipsis inserted after final word break

# modified by Mark Dickson <mark@sitesteaders.com> 2008-12-18
# Option to truncate to last full word
# Option to include a 'more' link
# Check for nil last child

# Copied from http://pastie.textmate.org/342485, 
# based on http://henrik.nyh.se/2008/01/rails-truncate-html-helper

module TextHelper
  def strip_and_truncate(text, options={})
    truncate_text(strip_tags(text), options)
  end
  def strip_tags(text)
    text ||= ""
    text.gsub(/<\/?[^>\n]*>/, "").gsub(/&#\d+;/) {|m| puts m; m[2..-1].to_i.chr rescue '' }.gsub(/&\w+;/, "")
  end
  
  def quote_clump(quote_lines)
    txt = "<div class='quoted_text_holder'><a href='#' class='show_quoted_text_link'>#{TextHelper.escape_html(I18n.t('lib.text_helper.quoted_text_toggle', "show quoted text"))}</a><div class='quoted_text' style='display: none;'>"
    txt += quote_lines.join("\n")
    txt += "</div></div>"
    txt
  end

  # http://daringfireball.net/2010/07/improved_regex_for_matching_urls
  # released to the public domain
  AUTO_LINKIFY_PLACEHOLDER = "LINK-PLACEHOLDER"
  AUTO_LINKIFY_REGEX = %r{
    \b
    (                                            # Capture 1: entire matched URL
      (?:
        https?://                                # http or https protocol
        |                                        # or
        www\d{0,3}[.]                            # "www.", "www1.", "www2." … "www999."
        |                                        # or
        [a-z0-9.\-]+[.][a-z]{2,4}/               # looks like domain name followed by a slash
      )
      (?:                                        # One or more:
        [^\s()<>]+                               # Run of non-space, non-()<>
        |                                        # or
        \(([^\s()<>]+|(\([^\s()<>]+\)))*\)       # balanced parens, up to 2 levels
      )+
      (?:                                        # End with:
        \(([^\s()<>]+|(\([^\s()<>]+\)))*\)       # balanced parens, up to 2 levels
        |                                        # or
        [^\s`!()\[\]{};:'".,<>?«»“”‘’]           # not a space or one of these punct chars
      )
    ) | (
      #{AUTO_LINKIFY_PLACEHOLDER}
    )
  }xi

  # Converts a plaintext message to html, with newlinification, quotification, and linkification
  def format_message(message, url=nil, notification_id=nil)
    # insert placeholders for the links we're going to generate, before we go and escape all the html
    links = []
    placeholder_blocks = []
    message = message.gsub(AUTO_LINKIFY_REGEX) do |match|
      placeholder_blocks << if match == AUTO_LINKIFY_PLACEHOLDER
        AUTO_LINKIFY_PLACEHOLDER
      else
        s = $1
        link = s
        link = "http://#{link}" if link[0,3] == 'www'
        link = add_notification_to_link(link, notification_id) if notification_id
        link = URI.escape(link).gsub("'", "%27")
        links << link
        "<a href='#{ERB::Util.h(link)}'>#{ERB::Util.h(s)}</a>"
      end
      AUTO_LINKIFY_PLACEHOLDER
    end

    # now escape any html
    message = TextHelper.escape_html(message)

    # now put the links back in
    message = message.gsub(AUTO_LINKIFY_PLACEHOLDER) do |match|
      placeholder_blocks.shift
    end

    message = message.gsub(/\r?\n/, "<br/>\r\n")
    processed_lines = []
    quote_block = []
    message.split("\n").each do |line|
      # check for lines starting with '>'
      if /^(&gt;|>)/ =~ line
        quote_block << line
      else
        processed_lines << quote_clump(quote_block) if !quote_block.empty?
        quote_block = []
        processed_lines << line
      end
    end
    processed_lines << quote_clump(quote_block) if !quote_block.empty?
    message = processed_lines.join("\n")
    if url
      url = add_notification_to_link(url, notification_id) if notification_id
      links.unshift url
    end
    links.unshift message
  end
  
  def add_notification_to_link(url, notification_id)
    parts = "#{url}".split("#", 2)
    link = parts[0]
    link += link.match(/\?/) ? "&" : "?"
    link += "clear_notification_id=#{notification_id}"
    link += parts[1] if parts[1]
    link
  rescue
    return ""
  end

  def truncate_text(text, options={})
    max_length = options[:max_length] || 30
    ellipsis = options[:ellipsis] || I18n.t('lib.text_helper.ellipsis', '...')
    ellipsis_length = ellipsis.length
    actual_length = max_length - ellipsis_length
    
    # First truncate the text down to the bytes max, then lop off any invalid
    # unicode characters at the end.
    truncated = (text || "")[0,actual_length][/.{0,#{actual_length}}/mu]
    if truncated.length < text.length
      truncated + ellipsis
    else
      truncated
    end
  end
  
  def self.escape_html(text)
    CGI::escapeHTML text
  end
  
  def self.unescape_html(text)
    CGI::unescapeHTML text
  end
  
  def indent(text, spaces=2)
    text = text.to_s rescue ""
    indentation = " " * spaces
    text.gsub(/\n/, "\n#{indentation}")
  end
  
  def force_zone(time)
    (time.in_time_zone(@time_zone || Time.zone) rescue nil) || time
  end

  def self.date_string(start_date, style=:normal)
    return nil unless start_date
    start_date = start_date.in_time_zone.to_date rescue start_date.to_date
    today = Time.zone.today
    if style != :long
      if style != :no_words
        string = nil
        return string if start_date == today && (string = I18n.t('date.days.today', 'Today')) && string.strip.present?
        return string if start_date == today + 1 && (string = I18n.t('date.days.tomorrow', 'Tomorrow')) && string.strip.present?
        return string if start_date == today - 1 && (string = I18n.t('date.days.yesterday', 'Yesterday')) && string.strip.present?
        return string if start_date < today + 1.week && start_date >= today && (string = I18n.l(start_date, :format => :weekday) rescue nil) && string.strip.present?
      end
      return I18n.l(start_date, :format => :short) if start_date.year == today.year || style == :short
    end
    return I18n.l(start_date, :format => :medium)
  end
  def date_string(*args)
    TextHelper.date_string(*args)
  end

  def time_string(start_time, end_time=nil)
    start_time = start_time.in_time_zone rescue start_time
    end_time = end_time.in_time_zone rescue end_time
    return nil unless start_time
    result = I18n.l(start_time, :format => start_time.min == 0 ? :tiny_on_the_hour : :tiny)
    if end_time && end_time != start_time
      result = I18n.t('time.ranges.times', "%{start_time} to %{end_time}", :start_time => result, :end_time => time_string(end_time))
    end
    result
  end
  
  def datetime_span(*args)
    string = datetime_string(*args)
    if string && !string.empty? && args[0]
      "<span class='zone_cached_datetime' title='#{args[0].iso8601 rescue ""}'>#{string}</span>"
    else
      nil
    end
  end

  def datetime_string(start_datetime, datetime_type=:event, end_datetime=nil, shorten_midnight=false)
    start_datetime = start_datetime.in_time_zone rescue start_datetime
    return nil unless start_datetime
    end_datetime = end_datetime.in_time_zone rescue end_datetime
    if !datetime_type.is_a?(Symbol)
      datetime_type = :event
      end_datetime = nil
    end
    end_datetime = nil if datetime_type == :due_date

    def datetime_component(date_string, time, type)
      if type == :due_date
        I18n.t('time.due_date', "%{date} by %{time}", :date => date_string, :time => time_string(time))
      else
        I18n.t('time.event', "%{date} at %{time}", :date => date_string, :time => time_string(time))
      end
    end

    start_date_string = date_string(start_datetime, datetime_type == :verbose ? :long : :no_words)
    start_string = datetime_component(start_date_string, start_datetime, datetime_type)

    if !end_datetime || end_datetime == start_datetime
      if shorten_midnight && ((datetime_type == :due_date  && start_datetime.hour == 23 && start_datetime.min == 59) || (datetime_type == :event && start_datetime.hour == 0 && start_datetime.min == 0))
        start_date_string
      else
        start_string
      end
    else
      if start_datetime.to_date == end_datetime.to_date
        I18n.t('time.ranges.same_day', "%{date} from %{start_time} to %{end_time}", :date => start_date_string, :start_time => time_string(start_datetime), :end_time => time_string(end_datetime))
      else
        end_date_string = date_string(end_datetime, datetime_type == :verbose ? :long : :no_words)
        end_string = datetime_component(end_date_string, end_datetime, datetime_type)
        I18n.t('time.ranges.different_days', "%{start_date_and_time} to %{end_date_and_time}", :start_date_and_time => start_string, :end_date_and_time => end_string)
      end
    end
  end

  def time_ago_in_words_with_ago(time)
    I18n.t('#time.with_ago', '%{time} ago', :time => (time_ago_in_words time rescue ''))
  end

  # more precise than distance_of_time_in_words, and takes a number of seconds,
  # rather than two times. also assumes durations on the scale of hours or
  # less, so doesn't bother with days, months, or years
  def readable_duration(seconds)
    # keys stolen from ActionView::Helpers::DateHelper#distance_of_time_in_words
    case seconds
    when  0...60
      I18n.t('datetime.distance_in_words.x_seconds',
        { :one => "1 second", :other => "%{count} seconds" },
        :count => seconds.round)
    when 60...3600
      I18n.t('datetime.distance_in_words.x_minutes',
        { :one => "1 minute", :other => "%{count} minutes" },
        :count => (seconds / 60.0).round)
    else
      I18n.t('datetime.distance_in_words.about_x_hours',
        { :one => "about 1 hour", :other => "about %{count} hours" },
        :count => (seconds / 3600.0).round)
    end
  end

  def truncate_html(input, options={})
    doc = Nokogiri::HTML(input)
    options[:max_length] ||= 250
    num_words = options[:num_words] || (options[:max_length] / 5) || 30
    truncate_string = options[:ellipsis] || I18n.t('lib.text_helper.ellipsis', '...')
    truncate_string += options[:link] if options[:link]
    truncate_elem = Nokogiri::HTML("<span>" + truncate_string + "</span>").at("span")
   
    current = doc.children.first
    count = 0
   
    while true
      # we found a text node
      if current.is_a?(Nokogiri::XML::Text)
        count += current.text.split.length
        # we reached our limit, let's get outta here!
        break if count > num_words
        previous = current
      end
   
      if current.children.length > 0
        # this node has children, can't be a text node,
        # lets descend and look for text nodes
        current = current.children.first
      elsif !current.next.nil?
        #this has no children, but has a sibling, let's check it out
        current = current.next
      else 
        # we are the last child, we need to ascend until we are
        # either done or find a sibling to continue on to
        n = current
        while !n.is_a?(Nokogiri::HTML::Document) and n.parent.next.nil?
          n = n.parent
        end
   
        # we've reached the top and found no more text nodes, break
        if n.is_a?(Nokogiri::HTML::Document)
          break;
        else
          current = n.parent.next
        end
      end
    end
   
    if count >= num_words
      unless count == num_words
        new_content = current.text.split
        
        # If we're here, the last text node we counted eclipsed the number of words
        # that we want, so we need to cut down on words.  The easiest way to think about
        # this is that without this node we'd have fewer words than the limit, so all
        # the previous words plus a limited number of words from this node are needed.
        # We simply need to figure out how many words are needed and grab that many.
        # Then we need to -subtract- an index, because the first word would be index zero.
        
        # For example, given:
        # <p>Testing this HTML truncater.</p><p>To see if its working.</p>
        # Let's say I want 6 words.  The correct returned string would be:
        # <p>Testing this HTML truncater.</p><p>To see...</p>
        # All the words in both paragraphs = 9
        # The last paragraph is the one that breaks the limit.  How many words would we
        # have without it? 4.  But we want up to 6, so we might as well get that many.
        # 6 - 4 = 2, so we get 2 words from this node, but words #1-2 are indices #0-1, so
        # we subtract 1.  If this gives us -1, we want nothing from this node. So go back to
        # the previous node instead.
        index = num_words-(count-new_content.length)-1
        if index >= 0
          new_content = new_content[0..index]
          current.add_previous_sibling(truncate_elem)
          new_node = Nokogiri::XML::Text.new(new_content.join(' '), doc)
          truncate_elem.add_previous_sibling(new_node)
          current = current.previous
        else
          current = previous
          # why would we do this next line? it just ends up xml escaping stuff
          #current.content = current.content
          current.add_next_sibling(truncate_elem)
          current = current.next
        end
      end
   
      # remove everything else
      while !current.is_a?(Nokogiri::HTML::Document)
        while !current.next.nil?
          current.next.remove
        end
        current = current.parent
      end
    end
   
    # now we grab the html and not the text.
    # we do first because nokogiri adds html and body tags
    # which we don't want
    res = doc.at_css('body').inner_html rescue nil
    res ||= doc.root.children.first.inner_html rescue ""
    res && res.html_safe
  end

  def self.make_subject_reply_to(subject)
    blank_re = I18n.t('#subject_reply_to', "Re: %{subject}", :subject => '')
    return subject if subject.starts_with?(blank_re)
    I18n.t('#subject_reply_to', "Re: %{subject}", :subject => subject)
  end

  class MarkdownSafeBuffer < String; end
  # use this to flag interpolated parameters as markdown-safe (see
  # mt below) so they get eval'ed rather than escaped, e.g.
  #  mt(:add_description, :example => markdown_safe('`1 + 1 = 2`'))
  def markdown_safe(string)
    MarkdownSafeBuffer.new(string)
  end

  def markdown_escape(string)
    return string if string.is_a?(MarkdownSafeBuffer)
    markdown_safe(string.gsub(/([\\`\*_\{\}\[\]\(\)\#\+\-\.!])/, '\\\\\1'))
  end

  # use this rather than t() if the translation contains trusted markdown
  def mt(*args)
    inlinify = :auto
    if args.last.is_a?(Hash)
      options = args.last
      inlinify = options.delete(:inlinify) if options.has_key?(:inlinify)
      options.each_pair do |key, value|
        next unless value.is_a?(String) && !value.is_a?(MarkdownSafeBuffer) && !value.is_a?(ActiveSupport::SafeBuffer)
        next if key == :wrapper
        options[key] = markdown_escape(value).gsub(/\s+/, ' ').strip
      end
    end
    translated = t(*args)
    translated = ERB::Util.h(translated) unless translated.html_safe?
    result = RDiscount.new(translated).to_html.strip
    # Strip wrapping <p></p> if inlinify == :auto && they completely wrap the result && there are not multiple <p>'s
    result.gsub!(/<\/?p>/, '') if inlinify == :auto && result =~ /\A<p>.*<\/p>\z/m && !(result =~ /.*<p>.*<p>.*/m)
    result.html_safe.strip
  end
end
