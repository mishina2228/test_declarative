$LOAD_PATH << File.expand_path('../../lib', __FILE__)

# Test with test/unit for older Rubies
def gemfile_name
  gemfile = ENV['BUNDLE_GEMFILE']
  raise 'bundler is required for test.' unless gemfile
  File.basename(gemfile)
end

GEMFILE = gemfile_name
case GEMFILE
when 'Gemfile'
  # Minitest >= 5
  require 'minitest/autorun'
  TEST_CASE = Minitest::Test
  RUNNER = Minitest::Unit
when 'Gemfile.minitest4'
  # Minitest < 5
  require 'minitest/autorun'
  TEST_CASE = MiniTest::Unit::TestCase
  RUNNER = MiniTest::Unit
when 'Gemfile.unit-test'
  # Latest test-unit
  require 'test-unit'
  require 'test/unit/testresult'
  TEST_CASE = Test::Unit::TestCase
  RUNNER = Test::Unit::TestResult
when 'Gemfile.empty'
  # Test for stdlib minitest.
  # test-unit and minitest were removed from stdlib at Ruby 2.2.
  # https://bugs.ruby-lang.org/issues/9711
  require 'minitest/autorun'
  TEST_CASE = MiniTest::Unit::TestCase
  RUNNER = MiniTest::Unit
else
  raise "Unknown gemfile: #{gemfile}"
end

require 'test_declarative'

class TestDeclarativeTest < TEST_CASE
  def test_responds_to_test
    assert self.class.respond_to?(:test)
  end

  def test_adds_a_test_method
    called = false
    TEST_CASE.test('some test') { called = true }
    case GEMFILE
    when 'Gemfile'
      TEST_CASE.new(:test_some_test).run {}
    when 'Gemfile.unit-test'
      # This module does not inherit unit test.
      # It has already implemented from test unit v2.3.0.
      # Run original test unit just in case.
      TEST_CASE.new("test: some test").run(RUNNER.new) {}
    else
      TEST_CASE.new(:test_some_test).run(RUNNER.new) {}
    end
    assert called
  end

  # Run only Minitest is required
  if %w[Gemfile Gemfile.minitest4].include?(GEMFILE)
    def test_not_to_print_deprecated_warnings
      targets = []
      targets << MiniTest::Unit::TestCase if defined?(MiniTest::Unit::TestCase)
      targets << Minitest::Test           if defined?(Minitest::Test)
      targets << Module
      begin
        targets.each do |target|
          target.class_eval do
            alias :orig_test :test
            undef :test
          end
        end

        _out, err = capture_io do
          load 'test_declarative.rb'
        end
        refute_includes err, 'test_declarative is deprecated for Minitest::Unit::TestCase'
        refute_includes err, 'test_declarative is deprecated for Minitest::Test'
      ensure
        targets.each do |target|
          target.class_eval do
            alias :test :orig_test unless target.respond_to?(:test)
          end
        end
      end
    end
  end
end
