module AutoCompleteMacrosHelper      
  # Adds AJAX autocomplete functionality to the text input field with the 
  # DOM ID specified by +field_id+.
  #
  # This function expects that the called action returns an HTML <ul> list,
  # or nothing if no entries should be displayed for autocompletion.
  #
  # You'll probably want to turn the browser's built-in autocompletion off,
  # so be sure to include an <tt>autocomplete="off"</tt> attribute with your text
  # input field.
  #
  # The autocompleter object is assigned to a Javascript variable named <tt>field_id</tt>_auto_completer.
  # This object is useful if you for example want to trigger the auto-complete suggestions through
  # other means than user input (for that specific case, call the <tt>activate</tt> method on that object). 
  # 
  # Required +options+ are:
  # <tt>:url</tt>::                  URL to call for autocompletion results
  #                                  in url_for format.
  # 
  # Addtional +options+ are:
  # <tt>:update</tt>::               Specifies the DOM ID of the element whose 
  #                                  innerHTML should be updated with the autocomplete
  #                                  entries returned by the AJAX request. 
  #                                  Defaults to <tt>field_id</tt> + '_auto_complete'
  # <tt>:callback</tt>::             This function is called just before the 
  #                                  Request is actually made, allowing you to 
  #                                  modify the querystring that is sent to the 
  #                                  server. The function receives the 
  #                                  completer’s input field and the default 
  #                                  querystring (‘value=XXX’) as parameters. 
  #                                  You should return the querystring you want 
  #                                  used, including the default part.  #                               
  # <tt>:with</tt>::                 A JavaScript expression specifying the
  #                                  parameters for the XMLHttpRequest. This defaults
  #                                  to 'fieldname=value'. Overrides :callback.
  # <tt>:frequency</tt>::            Determines the time to wait after the last keystroke
  #                                  for the AJAX request to be initiated.
  # <tt>:indicator</tt>::            Specifies the DOM ID of an element which will be
  #                                  displayed while autocomplete is running.
  # <tt>:tokens</tt>::               A string or an array of strings containing
  #                                  separator tokens for tokenized incremental 
  #                                  autocompletion. Example: <tt>:tokens => ','</tt> would
  #                                  allow multiple autocompletion entries, separated
  #                                  by commas.
  # <tt>:min_chars</tt>::            The minimum number of characters that should be
  #                                  in the input field before an Ajax call is made
  #                                  to the server.
  # <tt>:on_hide</tt>::              A Javascript expression that is called when the
  #                                  autocompletion div is hidden. The expression
  #                                  should take two variables: element and update.
  #                                  Element is a DOM element for the field, update
  #                                  is a DOM element for the div from which the
  #                                  innerHTML is replaced.
  # <tt>:on_show</tt>::              Like on_hide, only now the expression is called
  #                                  then the div is shown.
  # <tt>:update_element</tt>::       Hook for a custom function to replace the 
  #                                  built-in function that adds the list item 
  #                                  text to the input field. The custom 
  #                                  function is called after the element has 
  #                                  been updated (i.e. when the user has 
  #                                  selected an entry). The function receives 
  #                                  one parameter only: the selected item (the 
  #                                  li item selected)
  # <tt>:after_update_element</tt>:: A Javascript expression that is called when the
  #                                  user has selected one of the proposed values. 
  #                                  The expression should take two variables: element and value.
  #                                  Element is a DOM element for the field, value
  #                                  is the value selected by the user.
  # <tt>:select</tt>::               Pick the class of the element from which the value for 
  #                                  insertion should be extracted. If this is not specified,
  #                                  the entire element is used.
  # <tt>:method</tt>::               Specifies the HTTP verb to use when the autocompletion
  #                                  request is made. Defaults to POST.
  def auto_complete_field(field_id, options = {})
    function =  "var #{field_id}_auto_completer = new Ajax.Autocompleter("
    function << "'#{field_id}', "
    function << "'" + (options[:update] || "#{field_id}_auto_complete") + "', "
    function << "'#{url_for(options[:url])}'"
    
    js_options = {}
    js_options[:tokens] = array_or_string_for_javascript(options[:tokens]) if options[:tokens]
    if options[:with]
      js_options[:callback]   = "function(element, value) { return #{options[:with]} }"
    elsif options[:callback]
      js_options[:callback] = options[:callback]
    end
    js_options[:indicator]  = "'#{options[:indicator]}'" if options[:indicator]
    js_options[:select]     = "'#{options[:select]}'" if options[:select]
    js_options[:paramName]  = "'#{options[:param_name]}'" if options[:param_name]
    js_options[:frequency]  = "#{options[:frequency]}" if options[:frequency]
    js_options[:method]     = "'#{options[:method].to_s}'" if options[:method]
    
    js_options[:select]     = "'autocomplete_values'" if options[:append]

    { :after_update_element => :afterUpdateElement, 
      :update_element => :updateElement, :on_show => :onShow, 
      :on_hide => :onHide, :min_chars => :minChars }.each do |k,v|
      js_options[v] = options[k] if options[k]
    end

    function << (', ' + options_for_javascript(js_options) + ')')

    javascript_tag(function)
  end
  
  # Use this method in your view to generate a return for the AJAX autocomplete requests.
  #
  # Example action:
  #
  #   def auto_complete_for_item_title
  #     @items = Item.find(:all, 
  #       :conditions => [ 'LOWER(description) LIKE ?', 
  #       '%' + request.raw_post.downcase + '%' ])
  #     render :inline => "<%= auto_complete_result(@items, 'description') %>"
  #   end
  #
  # The auto_complete_result can of course also be called from a view belonging to the 
  # auto_complete action if you need to decorate it further.
  def auto_complete_result(entries, field, phrase = nil, prepend = "")
    return unless entries
    fullfield = "" if fullfield.nil?
    items = entries.map do |entry| 
      content_tag("li", phrase ? highlight(entry[field], phrase) : h(entry[field])\
        + content_tag('span', prepend + " " + h(entry[field]), :style => "display: none", :class => "autocomplete_values" )) 
    end
    content_tag("ul", items.uniq)
  end
  
  # Wrapper for text_field with added AJAX autocompletion functionality.
  #
  # In your controller, you'll need to define an action called
  # auto_complete_for to respond the AJAX calls,
  # 
  def text_field_with_auto_complete(object, method, tag_options = {}, completion_options = {})
    if (tag_options[:index])
      tag_name = "#{object}_#{tag_options[:index]}_#{method}"
    else
      tag_name = "#{object}_#{method}"
    end
    content_for :styles, auto_complete_stylesheet unless completion_options[:skip_style]
    text_field(object, method, tag_options) +
    content_tag("div", "", :id => tag_name + "_auto_complete", :class => "auto_complete") +
    auto_complete_field(tag_name, { :url => { :action => "auto_complete_for_#{object}_#{method}" } }.update(completion_options))
  end

  private
    def auto_complete_stylesheet
      content_tag('style', <<-EOT, :type => Mime::CSS)
        div.auto_complete {
          width: 350px;
          background: #fff;
        }
        div.auto_complete ul {
          border:1px solid #888;
          margin:0;
          padding:0;
          width:100%;
          list-style-type:none;
        }
        div.auto_complete ul li {
          margin:0;
          padding:3px;
        }
        div.auto_complete ul li.selected {
          background-color: #ffb;
        }
        div.auto_complete ul strong.highlight {
          color: #800; 
          margin:0;
          padding:0;
        }
      EOT
    end

end   
