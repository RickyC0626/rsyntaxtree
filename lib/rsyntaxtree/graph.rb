#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#==========================
# graph.rb
#==========================
#
# Image utility functions to inspect text font metrics
#
# This file is part of RSyntaxTree, which is a ruby port of Andre Eisenbach's
# excellent program phpSyntaxTree.
#
# Copyright (c) 2007-2021 Yoichiro Hasebe <yohasebe@gmail.com>
# Copyright (c) 2003-2004 Andre Eisenbach <andre@ironcreek.net>

require 'rmagick'
include Magick

class Graph

  def initialize(e_list, metrics, symmetrize, color, leafstyle, multibyte, font, font_size)

    # Set class-specific parameters beforehand in subclass

    # Store parameters
    @e_list     = e_list
    @m          = metrics
    @multibyte  = multibyte
    @leafstyle  = leafstyle
    @symmetrize = symmetrize

    # Calculate image dimensions
    @e_height = font_size + @m[:e_padd] * 2
    h         = @e_list.get_level_height
    w      = calc_level_width(0)
    @width = w
    @height   = h * @e_height + (h-1) * (@m[:v_space] + font_size) + @m[:b_topbot] * 2

    # Initialize the image and colors
    @col_bg   = "none"
    @col_fg   = "black"
    @col_line = "black"

    if color
      @col_node  = "blue"
      @col_leaf  = "green"
      @col_trace = "red"
    else
      @col_node  = "black"
      @col_leaf  = "black"
      @col_trace = "black"
    end

    @main_height = img_get_txt_height("l", font, font_size)
    @sub_size = (font_size * SUBSCRIPT_CONST)
    @sub_space_width = img_get_txt_width("l", font, @sub_size)
  end

  def img_get_txt_metrics(text, font, font_size, multiline)

    background = Image.new(1, 1)

    gc = Draw.new
    gc.annotate(background, 0, 0, 0, 0, text) do |gc|
      gc.font = font
      gc.pointsize = font_size
      gc.gravity = CenterGravity
      gc.stroke = 'none'
    end

    if multiline
      metrics = gc.get_multiline_type_metrics(background, text)
    else
      metrics = gc.get_type_metrics(background, text)
    end
    return metrics
  end

  # Calculate the width of the element. If the element is
  # a node, the calculation will be performed recursively
  # for all child elements.
  def calc_element_width(e)
    w = 0
    content = e.content.gsub("<>", " ")

    children = @e_list.get_children(e.id)

    if(children.length == 0)
      w = img_get_txt_width(content, @font, @font_size) + @font_size
    else
      children.each do |child|
        child_e = @e_list.get_id(child)
        w += calc_element_width(child_e)
      end

      tw = img_get_txt_width(content, @font, @font_size) + @font_size
      if(tw > w)
        fix_child_size(e.id, w, tw)
        w = tw
      end
    end

    @e_list.set_element_width(e.id, w)
    return w
  end

  # Calculate the width of all elements in a certain level
  def calc_level_width(level)
    w = 0
    e = @e_list.get_first
    while e
      if(e.level == level)
        x = calc_element_width(e)
        w += x
      end
      e = @e_list.get_next
    end
    return w
  end

  def calc_children_width(id)
    left = 0
    right = 0
    c_list = @e_list.get_children(id)
    return nil if c_list.empty?

    c_list.each do |c|
      left =  c.indent if indent == 0 or left > c.indent
    end
    c_list.each do |c|
      right = c.indent + e.width if c.indent + c.width > right
    end
    return [left, right]
  end

  def get_children_indent(id)
    calc_children_width(id)[0]
  end

  def get_children_width(id)
    calc_children_width(id)[1] - get_children_indent(id)
  end

  # Parse the elements in the list top to bottom and
  #   draw the elements into the image.
  #   As we it iterate through the levels, the element
  #   indentation is calculated.
  def parse_list

    # Calc element list recursively....
    e_arr = @e_list.get_elements

    h = @e_list.get_level_height

    h.times do |i|
      x = 0
      e_arr.each do |j|

        if (j.level == i)
          cw = @e_list.get_element_width(j.id)
          parent_indent = @e_list.get_indent(j.parent)
          if (x <  parent_indent)
            x = parent_indent
          end
          @e_list.set_indent(j.id, x)

          if !@symmetrize
            draw_element(x, i, cw, j.content, j.type)
            if(j.parent != 0 )
              words = j.content.split(" ")
              unless @leafstyle == "nothing" && ETYPE_LEAF == j.type
                if (@leafstyle == "auto" && ETYPE_LEAF == j.type && x == parent_indent)
                  if words.length > 1 || j.triangle
                    txt_width = img_get_txt_width(j.content, @font, @font_size)
                    triangle_to_parent(x, i, cw, txt_width, @symmetrize)
                  else
                    line_to_parent(x, i, cw, @e_list.get_indent(j.parent), @e_list.get_element_width(j.parent))
                  end
                else
                  line_to_parent(x, i, cw, @e_list.get_indent(j.parent), @e_list.get_element_width(j.parent))
                end
              end
            end
          end
          x += cw
        end
      end
    end
    return true if !@symmetrize

    elements_to_draw = {}
    triangles_to_draw = []
    lines_to_draw = []

    lmost = {:level => nil, :value => nil, :type => nil}
    rmost = nil
    h.times do |i|
      curlevel = h - i - 1
      e_arr.each_with_index do |j, idx|
        if (j.level == curlevel)
          # Draw a line to the parent element
          children = @e_list.get_children(j.id)

          tw = img_get_txt_width(j.content, @font, @font_size)
          if children.length > 0
            left, right = -1, -1
            children.each do |child|
              k = @e_list.get_id(child)
              kw = img_get_txt_width(k.content, @font, @font_size)
              left = k.indent + kw / 2 if k.indent + kw / 2 < left or left == -1
              right = k.indent + kw / 2 if k.indent + kw / 2 > right
            end

            elements_to_draw[j.id] = {:left => left, :curlevel => curlevel, :width => right - left, :content => j.content, :type => j.type}
            @e_list.set_indent(j.id, left + (right - left) / 2 -  tw / 2)

            children.each do |child|
              k = @e_list.get_id(child)
              words = k.content.split(" ")
              dw = img_get_txt_width(k.content, @font, @font_size)

              children2 = @e_list.get_children(k.id)

              unless @leafstyle == "nothing" && ETYPE_LEAF == k.type
                if (@leafstyle == "auto" && ETYPE_LEAF == k.type)
                  if words.length > 1 || k.triangle
                    txt_width = img_get_txt_width(k.content, @font, @font_size)
                    triangles_to_draw << {:indent => k.indent, :curlevel => curlevel + 1, :width1 => dw, :width2 => txt_width}
                  else
                    lines_to_draw << {:indent1 => k.indent, :curlevel => curlevel + 1, :width1 => dw, :indent2 => j.indent, :width2 => tw}
                  end
                else
                  lines_to_draw << {:indent1 => k.indent, :curlevel => curlevel + 1, :width1 => dw, :indent2 => j.indent, :width2 => tw}
                end
              end
            end

          end
          elements = e_arr.select do |l|
            l.level == curlevel && @e_list.get_children(l.id).empty?
          end

          elements.each.with_index do |l, idx|
            lw = img_get_txt_width(l.content, @font, @font_size)
            left = l.indent
            right = left + lw
            unless elements_to_draw.include? l.id
              elements_to_draw[l.id] = {:left => left, :curlevel => curlevel, :width => right - left, :content => l.content, :type => l.type}
            end
          end
        end
      end

      e_arr.each do |e|
        lpos = e.indent - img_get_txt_width(e.content, @font, @font_size) / 2
        next if lpos > 0
        if !lmost[:value] || lmost[:value] > lpos
          lmost[:level] = e.level
          lmost[:value] = lpos
          lmost[:type] = e
        end
        rpos = e.indent + e.width
        rmost =  rpos if !rmost || rmost < rpos
      end
    end

    offset = 0
    if lmost[:level] != h - 1
      offset = lmost[:value] / -2
      new_width = rmost
      @width = new_width + offset
    end

    elements_to_draw.each do |k, v|
      draw_element(v[:left] + offset, v[:curlevel], v[:width], v[:content], v[:type])
    end
    triangles_to_draw.each do |v|
      triangle_to_parent(v[:indent] + offset, v[:curlevel], v[:width1], v[:width2])
    end
    lines_to_draw.each do |v|
      line_to_parent(v[:indent1] + offset, v[:curlevel], v[:width1], v[:indent2] + offset, v[:width2])
    end
  end

  # Calculate top position from row (level)
  def row2px(row)
   @m[:b_topbot] + @e_height * row + (@m[:v_space] + @font_size) * row
  end

  def get_txt_only(text)
    text = text.strip
    if /\A([\+\-\=\*\#\~]+).+/ =~ text
      prefix = $1
      prefix_l = Regexp.escape(prefix)
      prefix_r = Regexp.escape(prefix.reverse)
      if /\A#{prefix_l}(.+)#{prefix_r}\z/ =~ text
        return $1
      end
    end
    return text
  end

  def img_get_txt_height(text, font, font_size, multiline = true)
    metrics = img_get_txt_metrics(text, font, font_size, multiline)
    y = metrics.height
    return y
  end
end
