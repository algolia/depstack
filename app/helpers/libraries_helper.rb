require 'github/markup'
require 'open-uri'

module LibrariesHelper

  def render_readme(user, name)
    %w{README.md README.markdown README.textile README.rdoc Readme.md Readme.markdown Readme.textile Readme.rdoc README.rst Readme.rst README}.each do |f|
      content = open("https://raw.github.com/#{user}/#{name}/HEAD/#{f}").read rescue nil
      next if content.blank?
      code = GitHub::Markup.render(f, content).gsub(/(?!<pre>)<code>(.*?)<\/code>/m) do |match|
        match["\n"] ? "<pre>#{match}</pre>" : "<code>#{match}</code>"
      end.gsub(/(?:```|<code>)(ruby|js|html|erb|css|java|shell|sh|python|php|html|objc|scss)\n(.*)(?:<\/code>|```)/m, '<code class="\1">\2</code>')
      return html_syntax_highlighter(f == 'README' ? "<pre>#{code}</pre>" : code).html_safe
    end
    nil
  end

  def html_syntax_highlighter(html)
    doc = Nokogiri::HTML(html)
    doc.search("//code").each do |code|
      next if code[:class].nil?
      # convert github code name to highlight_code's name
      lang = case code[:class].to_s
      when "objc"
        "objective-c"
      when "php"
        :js
      else
        code[:class]
      end
      code.replace highlight_code(lang, code.text.rstrip)
    end
    doc.to_s
  end

end
