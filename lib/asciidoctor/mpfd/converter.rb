require "asciidoctor"
require "asciidoctor/mpfd"
require "asciidoctor/standoc/converter"
require "isodoc/mpfd/html_convert"
require "isodoc/mpfd/word_convert"
require_relative "section"
require "fileutils"

module Asciidoctor
  module Mpfd

    # A {Converter} implementation that generates MPFD output, and a document
    # schema encapsulation of the document for validation
    #
    class Converter < Standoc::Converter

      register_for "mpfd"

      def metadata_author(node, xml)
        xml.contributor do |c|
          c.role **{ type: "author" }
          c.organization do |a|
            a.name "Mandatory Provident Fund Schemes Authority"
            a.abbreviation "MPFA"
          end
        end
      end

      def metadata_publisher(node, xml)
        xml.contributor do |c|
          c.role **{ type: "publisher" }
          c.organization do |a|
            a.name "Mandatory Provident Fund Schemes Authority"
            a.abbreviation "MPFA"
          end
        end
      end

      def metadata_committee(node, xml)
        xml.editorialgroup do |a|
          a.committee node.attr("committee"),
            **attr_code(type: node.attr("committee-type"))
          i = 2
          while node.attr("committee_#{i}") do
            a.committee node.attr("committee_#{i}"),
              **attr_code(type: node.attr("committee-type_#{i}"))
            i += 1
          end
        end
      end

      def metadata_status(node, xml)
        xml.status(**{ format: "plain" }) { |s| s << node.attr("status") }
      end

      def metadata_id(node, xml)
        xml.docidentifier { |i| i << node.attr("docnumber") }
      end

      def metadata_copyright(node, xml)
        from = node.attr("copyright-year") || Date.today.year
        xml.copyright do |c|
          c.from from
          c.owner do |owner|
            owner.organization do |o|
              o.name "Mandatory Provident Fund Schemes Authority"
              o.abbreviation "MPFA"
            end
          end
        end
      end

      def title_validate(root)
        nil
      end

      def makexml(node)
        result = ["<?xml version='1.0' encoding='UTF-8'?>\n<mpfd-standard>"]
        @draft = node.attributes.has_key?("draft")
        result << noko { |ixml| front node, ixml }
        result << noko { |ixml| middle node, ixml }
        result << "</mpfd-standard>"
        result = textcleanup(result.flatten * "\n")
        ret1 = cleanup(Nokogiri::XML(result))
        validate(ret1)
        ret1.root.add_namespace(nil, MPFD_NAMESPACE)
        ret1
      end

      def doctype(node)
        d = node.attr("doctype")
=begin
        unless %w{policy-and-procedures best-practices circular supporting-document report legal directives proposal standard}.include? d
          warn "#{d} is not a legal document type: reverting to 'standard'"
          d = "standard"
        end
=end
        d
      end

      def pdf_convert(filename)
        url = "#{Dir.pwd}/#{filename}.html"
        pdfjs = File.join(File.dirname(__FILE__), 'pdf.js')
        system "export NODE_PATH=$(npm root --quiet -g);
                node #{pdfjs} file://#{url} #{filename}.pdf"
      end

      def document(node)
        init(node)
        ret1 = makexml(node)
        ret = ret1.to_xml(indent: 2)
        unless node.attr("nodoc") || !node.attr("docfile")
          filename = node.attr("docfile").gsub(/\.adoc/, ".xml").
            gsub(%r{^.*/}, "")
          File.open(filename, "w") { |f| f.write(ret) }
          html_converter(node).convert filename unless node.attr("nodoc")
          word_converter(node).convert filename unless node.attr("nodoc")
          pdf_convert(filename.sub(/\.xml$/, "")) unless node.attr("nodoc")
        end
        @files_to_delete.each { |f| FileUtils.rm f }
        ret
      end

      def validate(doc)
        content_validate(doc)
        schema_validate(formattedstr_strip(doc.dup),
                        File.join(File.dirname(__FILE__), "mpfd.rng"))
      end

      def literal(node)
        noko do |xml|
          xml.figure **id_attr(node) do |f|
            figure_title(node, f)
            f.pre node.lines.join("\n")
          end
        end
      end

      def style(n, t)
        return
      end

      def html_converter(node)
        IsoDoc::Mpfd::HtmlConvert.new(html_extract_attributes(node))
      end

      def word_converter(node)
        IsoDoc::Mpfd::WordConvert.new(doc_extract_attributes(node))
      end

      def inline_quoted(node)
        noko do |xml|
          case node.type
          when :emphasis then xml.em node.text
          when :strong then xml.strong node.text
          when :monospaced then xml.tt node.text
          when :double then xml << "\"#{node.text}\""
          when :single then xml << "'#{node.text}'"
          when :superscript then xml.sup node.text
          when :subscript then xml.sub node.text
          when :asciimath then stem_parse(node.text, xml)
          else
            case node.role
            when "strike" then xml.strike node.text
            when "smallcap" then xml.smallcap node.text
            when "keyword" then xml.keyword node.text
            else
              xml << node.text
            end
          end
        end.join
      end

    end
  end
end
