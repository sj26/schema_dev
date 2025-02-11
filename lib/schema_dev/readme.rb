# frozen_string_literal: true

require 'pathname'

module SchemaDev
  class Readme
    def self.update(config)
      new(config.matrix(with_dbversion: true)).update
    end

    attr_accessor :matrix, :readme

    def initialize(matrix)
      self.matrix = matrix
      self.readme = Pathname.new('README.md')
    end

    def update
      return false unless readme.exist?

      lines = readme.readlines
      newlines = sub_matrix(lines.dup)
      newlines = sub_templates(newlines)
      newreadme = Gem.new(Pathname.pwd.basename.to_s).erb(newlines.join)
      if newreadme != lines.join
        readme.write newreadme
        true
      end
    end

    def sub_matrix(lines)
      replace_block(lines, %r{^\s*<!-- SCHEMA_DEV: MATRIX}) do |contents|
        contents << "<!-- SCHEMA_DEV: MATRIX - begin -->\n"
        contents << "<!-- These lines are auto-generated by schema_dev based on schema_dev.yml -->\n"
        matrix.group_by { |e| e.slice(:ruby, :activerecord) }.each do |pair, items|
          dbs = items.map do |item|
            db = item[:db]
            db = "#{db}:#{item[:dbversion]}" if item.key?(:dbversion)
            "**#{db}**"
          end.to_sentence(last_word_connector: ' or ')
          contents << "* ruby **#{pair[:ruby]}** with activerecord **#{pair[:activerecord]}**, using #{dbs}\n"
        end
        contents << "\n"
        contents << "<!-- SCHEMA_DEV: MATRIX - end -->\n"
      end
    end

    def sub_templates(lines)
      Pathname.glob(SchemaDev::Templates.root + 'README' + '*.md.erb').each do |template|
        lines = sub_template(template, lines)
      end
      lines
    end

    def sub_template(template, lines)
      key = template.basename('.md.erb').to_s.upcase.tr('.', ' ')

      replace_block(lines, %r{^\s*<!-- SCHEMA_DEV: TEMPLATE #{key}}) do |contents|
        contents << "<!-- SCHEMA_DEV: TEMPLATE #{key} - begin -->\n"
        contents << "<!-- These lines are auto-inserted from a schema_dev template -->\n"
        contents << template.readlines
        contents << "\n"
        contents << "<!-- SCHEMA_DEV: TEMPLATE #{key} - end -->\n"
      end
    end

    def replace_block(lines, pattern)
      before = lines.take_while { |e| e !~ pattern }
      return lines if before == lines

      after = lines.reverse.take_while { |e| e !~ pattern }.reverse
      contents = []
      yield contents
      before + contents + after
    end
  end
end
