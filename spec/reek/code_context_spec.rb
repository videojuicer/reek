require File.dirname(__FILE__) + '/../spec_helper.rb'

require 'reek/block_context'
require 'reek/if_context'
require 'reek/class_context'
require 'reek/module_context'
require 'reek/method_context'
require 'reek/stop_context'

include Reek

describe CodeContext do
  context 'to_s' do
    it "reports the full context" do
      element = StopContext.new
      element = ModuleContext.new(element, Name.new(:mod), s(:module, :mod, nil))
      element = ClassContext.new(element, [0, :klass])
      element = MethodContext.new(element, [0, :bad])
      element = BlockContext.new(element, nil)
      element.to_s.should match(/bad/)
      element.to_s.should match(/klass/)
      element.to_s.should match(/mod/)
    end

    it 'reports the method name via if context' do
      element1 = StopContext.new
      element2 = MethodContext.new(element1, [0, :bad])
      element3 = IfContext.new(element2, [0,1])
      BlockContext.new(element3, nil).to_s.should match(/bad/)
    end

    it 'reports the method name via nested blocks' do
      element1 = StopContext.new
      element2 = MethodContext.new(element1, [0, :bad])
      element3 = BlockContext.new(element2, nil)
      BlockContext.new(element3, nil).to_s.should match(/bad/)
    end
  end

  context 'instance variables' do
    it 'should pass instance variables down to the first class' do
      element = StopContext.new
      element = ModuleContext.new(element, Name.new(:mod), s(:module, :mod, nil))
      class_element = ClassContext.new(element, [0, :klass])
      element = MethodContext.new(class_element, [0, :bad])
      element = BlockContext.new(element, nil)
      element.record_instance_variable(:fred)
      class_element.variable_names.size.should == 1
      class_element.variable_names.should include(Name.new(:fred))
    end
  end

  context 'generics' do
    it 'should pass unknown method calls down the stack' do
      stop = StopContext.new
      def stop.bananas(arg1, arg2) arg1 + arg2 + 43 end
      element = ModuleContext.new(stop, Name.new(:mod), s(:module, :mod, nil))
      class_element = ClassContext.new(element, [0, :klass])
      element = MethodContext.new(class_element, [0, :bad])
      element = BlockContext.new(element, nil)
      element.bananas(17, -5).should == 55
    end
  end

  context 'name matching' do
    it 'should recognise itself in a collection of names' do
      element = StopContext.new
      element = ModuleContext.new(element, Name.new(:mod), s(:module, :mod, nil))
      element.matches?(['banana', 'mod']).should == true
    end

    it 'should recognise itself in a collection of REs' do
      element = StopContext.new
      element = ModuleContext.new(element, Name.new(:mod), s(:module, :mod, nil))
      element.matches?([/banana/, /mod/]).should == true
    end

    it 'should recognise its fq name in a collection of names' do
      element = StopContext.new
      element = ModuleContext.new(element, Name.new(:mod), s(:module, :mod, nil))
      element = ClassContext.create(element, [0, :klass])
      element.matches?(['banana', 'mod']).should == true
      element.matches?(['banana', 'mod::klass']).should == true
    end

    it 'should recognise its fq name in a collection of names' do
      element = StopContext.new
      element = ModuleContext.new(element, Name.new(:mod), s(:module, :mod, nil))
      element = ClassContext.create(element, [0, :klass])
      element.matches?([/banana/, /mod/]).should == true
      element.matches?([/banana/, /mod::klass/]).should == true
    end
  end

  context 'enumerating syntax elements' do
    context 'in an empty module' do
      before :each do
        @module_name = 'Emptiness'
        src = "module #{@module_name}; end"
        ast = src.to_reek_source.syntax_tree
        @ctx = CodeContext.new(nil, ast)
      end
      it 'yields no calls' do
        @ctx.each(:call) {|exp| raise "#{exp} yielded by empty module!"}
      end
      it 'yields one module' do
        mods = 0
        @ctx.each(:module) {|exp| mods += 1}
        mods.should == 1
      end
      it "yields the module's full AST" do
        @ctx.each(:module) {|exp| exp[1].should == @module_name.to_sym}
      end

      context 'with no block' do
        it 'returns an empty array of ifs' do
          @ctx.each(:if).should be_empty
        end
      end
    end

    context 'with a nested element' do
      before :each do
        @module_name = 'Loneliness'
        @method_name = 'calloo'
        src = "module #{@module_name}; def #{@method_name}; puts('hello') end; end"
        ast = src.to_reek_source.syntax_tree
        @ctx = CodeContext.new(nil, ast)
      end
      it 'yields no ifs' do
        @ctx.each(:if) {|exp| raise "#{exp} yielded by empty module!"}
      end
      it 'yields one module' do
        @ctx.each(:module).length.should == 1
      end
      it "yields the module's full AST" do
        @ctx.each(:module) {|exp| exp[1].should == @module_name.to_sym}
      end
      it 'yields one method' do
        @ctx.each(:defn).length.should == 1
      end
      it "yields the method's full AST" do
        @ctx.each(:defn) {|exp| exp[1].should == @method_name.to_sym}
      end

      context 'pruning the traversal' do
        it 'ignores the call inside the method' do
          @ctx.each(:call, [:defn]).should be_empty
        end
      end
    end

    it 'finds 3 ifs in a class' do
      src = <<EOS
class Scrunch
  def first
    return @field == :sym ? 0 : 3;
  end
  def second
    if @field == :sym
      @other += " quarts"
    end
  end
  def third
    raise 'flu!' unless @field == :sym
  end
end
EOS

      ast = src.to_reek_source.syntax_tree
      ctx = CodeContext.new(nil, ast)
      ctx.each(:if).length.should == 3
    end
  end
end
