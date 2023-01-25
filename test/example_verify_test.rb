# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require "yaml"
require_relative '../lib/rsyntaxtree'
require_relative '../lib/rsyntaxtree/utils'

class ExampleParserTest < Minitest::Test
  examples_dir = File.expand_path(File.join(__dir__, "..", "docs", "_examples"))
  svg_dir = File.expand_path(File.join(__dir__, "..", "docs", "assets", "svg"))

  Dir.glob("*.md", base: examples_dir).map do |md|
    md = File.join(examples_dir, md)
    config = YAML.load_file(md)
    rst = File.read(md).scan(/```([^`]+)```/m).last.first

    opts = {
      format: "png",
      leafstyle: "auto",
      fontstyle: "sans",
      fontsize: 16,
      margin: 1,
      vheight: 2.0,
      color: "on",
      symmetrize: "on",
      transparent: "off",
      polyline: "off"
    }
    name = nil
    config.each do |key, value|
      next if value.to_s == ""

      case key
      when "name"
        name = value
      when "colorization"
        opts[:color] = value
      when "polyline"
        opts[:polyline] = value
      when "symmetrization"
        opts[:symmetrize] = value
      when "connector"
        opts[:leafstyle] = value
      when "font"
        opts[:fontstyle] = case value
                           when /sans/i
                             "sans"
                           when /serif/i
                             "serif"
                           when /wqy/i
                             "cjk"
                           else
                             "sans"
                           end
      end
    end

    opts[:data] = rst
    rsg = RSyntaxTree::RSGenerator.new(opts)

    #################################
    # To test SVG, run the code below
    #################################
    svg = rsg.draw_svg
    opts[:svg] = svg
    svg_path = File.join(svg_dir, "#{name}.svg")
    svg_code = File.read(svg_path)
    puts "Creating example SVG test case: #{name}"

    define_method "test_#{name}" do
      assert_equal svg_code, opts[:svg]
    end

    ##########################################
    # To create SVG for the tests, comment-out
    # above block and run the code below
    ##########################################
    # File.open(File.join(svg_dir, "#{name}.svg"), "w") do |f|
    #   puts "Creating svg file: #{name}.svg"
    #   svg = rsg.draw_svg
    #   f.write(svg)
    # end

    ##########################################
    # To create SVG for the documentation,
    # comment-out above and run the code below
    ##########################################
    # png_dir = File.expand_path(File.join(__dir__, "..", "docs", "assets", "img"))
    # File.open(File.join(png_dir, "#{name}.png"), "w") do |f|
    #   puts "Creating png file: #{name}.png"
    #   png = rsg.draw_png
    #   f.write(png)
    # end
  end
end
