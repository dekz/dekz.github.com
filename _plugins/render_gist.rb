require 'open-uri'

module Jekyll
  class RenderGist <  Tags::HighlightBlock

    def initialize(tag_name, params, tokens)
      url, specified_language = params.split(' ')

      # https://gist.githubusercontent.com/edelabar/885585/raw/97636729211894478563debbe776c4a69bb19fce/example.txt
      # https://gist.githubusercontent.com/dekz/3e37d5aa399e7a7680f5/raw/dnsmasq.tmpl
      # https://gist.githubusercontent.com/dekz/789a59666c110c50045d/raw/a3d2746cdaa20e947a0496952c91b6a1fe272835/Dockerfile
      if %r|https://gist.githubusercontent.com/.*/(.*)/raw/(.*)/(.*\.([a-zA-Z]+))| =~ url
        @gist = $1
        @uuid = $2
        @file = $3
        file_language = $4
      elsif %r|https://gist.github.com/raw/(.*)/(.*)/(.*\.([a-zA-Z]+))| =~ url
        @gist = $1
        @uuid = $2
        @file = $3
        file_language = $4
      elsif %r|https://gist.githubusercontent.com/(.*)/(.*)/raw/(.*)/(.*)| =~ url
        @user = $1
      #  @gist = $2
        @uuid = $2
        @file = $4
      elsif %r|https://gist.githubusercontent.com/(.*)/(.*)/raw/(.*\.([a-zA-Z]+))| =~ url
        @user = $1
        @uuid = $2
        @file = $3
      elsif %r|https://gist.githubusercontent.com/(.*)/(.*)/raw/(.*\.([a-zA-Z]+))| =~ url
        @user = $1
        @uuid = $2
        @file = $3
      else
        $stderr.puts "Failed to parse gist URL '#{url}' from tag."
        $stderr.puts "URL should be in the form 'https://gist.githubusercontent.com/edelabar/885585/raw/97636729211894478563debbe776c4a69bb19fce/example.txt'"
        exit(1);
      end

      @language = specified_language || file_language
    end

    def get_gist_contents(gist,uuid,file,user)

      if gist
        gist_url = "https://gist.githubusercontent.com/#{user}/#{gist}/raw/#{uuid}/#{file}"
      else
        gist_url = "https://gist.githubusercontent.com/#{user}/#{uuid}/raw/#{file}"
      end

      begin
        open(gist_url).read
      rescue => error
        $stderr.puts "Unable to open gist URL: #{error}"
        exit(1);
      end

    end

    # Stolen from highlighter
    def render(context)
      @code = get_gist_contents(@gist,@uuid,@file,@user)
      @options = {}
      @lang = @language

      is_safe = !!context.registers[:site].safe

      output =
        case context.registers[:site].highlighter
          when 'pygments'
            render_pygments(@code, is_safe)
          when 'rouge'
            render_rouge(@code)
          else
            render_codehighlighter(@code)
          end
    end

  end
end

Liquid::Template.register_tag('render_gist', Jekyll::RenderGist)
